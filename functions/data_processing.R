
# Grabs the list of 3_day or 1_day csv data from phenocam website with spring and fall
get_site_roi_csvs = function(name, roi_files_, frequency_, 
                             metrics_ = c("gcc_mean","gcc_50", "gcc_75","gcc_90"), 
                             percentile_, roi_type_){
  idx      = is.element(roi_files_$site, name)
  idx2     = is.element(roi_files_$roitype, roi_type_)
  num_rois = length(idx[idx == TRUE])
  loc_rois = which(idx == TRUE & idx2 ==TRUE)
  plot_data      = data.frame()
  unix = "1970-01-01"
  roi  = 1000

  if (frequency_ == 1){
    for (i in loc_rois){
      downloadable_file = roi_files_$one_day_summary[i]
      df  = data.table::fread(downloadable_file)
      print (roi_files$roitype[i])
      print (downloadable_file)
      c   = smooth_ts(df, metrics = metrics_, force = TRUE, frequency_)
      plot_data = rbind(plot_data, c)
    }
  }
  if (frequency_ == 3){
    for (i in loc_rois){
      downloadable_file = roi_files_$three_day_summary[i]
      df  = data.table::fread(downloadable_file)
      print (roi_files$roitype[i])
      print (downloadable_file)
      c   = smooth_ts(df, metrics = metrics_, force = TRUE, frequency_)
      plot_data = rbind(plot_data, c)
    }
  }
  
  spring = transition_dates(plot_data,
                            percentile = percentile_,
                            reverse = FALSE)

  fall = transition_dates(plot_data,
                          percentile = percentile_,
                          reverse = TRUE)
  
  # Creating a header for the file to save out to (metadata)
  # format dates correctly (unix time to date format)
  spring[, 1:9] = apply(spring[, 1:9], 2, function(x)
    as.character(as.Date(x, origin = unix)))
  fall[, 1:9] = apply(fall[, 1:9], 2, function(x)
    as.character(as.Date(x, origin = unix)))

  # bind spring and fall phenology data in a coherent format
  phenology = rbind(spring,fall)
  rising_length = dim(spring)[1]
  falling_length = dim(fall)[1]
  direction = c(rep("rising", rising_length),
                rep("falling", falling_length))
  sitename = rep(name, rising_length + falling_length)
  veg_type = rep(roi_type_, rising_length + falling_length)
  roi_id = rep(sprintf("%04d",roi), rising_length + falling_length)

  phenology[, 1:9] = apply(phenology[, 1:9], 2, function(x)
    as.character(as.Date(x, origin = unix)))

  # bind in new labels
  phenology = cbind(sitename,veg_type,roi_id,direction,phenology)

  # drop NA lines
  phenology = na.omit(phenology)

  # create header with output information
  phenology_header = matrix("#",12,1)
# 
  # populate the header file
  phenology_header[2,1] = "# Transition date estimates"
  phenology_header[4,1] = sprintf("# Sitename: %s",name)
  phenology_header[5,1] = sprintf("# Vegetation Type: %s",roi_type_)
  phenology_header[6,1] = sprintf("# ROI ID: %04d",roi)
  phenology_header[7,1] = sprintf("# Aggregation period: %s", as.numeric(frequency_))
  phenology_header[8,1] = sprintf("# Year min: %s",
                                  min(strptime(as.matrix(phenology[, 5:13]),"%Y-%m-%d")$year +
                                        1900), # THIS IS UGLY THIS CAN BE SHORTER
                                  na.rm = TRUE)
  phenology_header[9,1] = sprintf("# Year max: %s",
                                  max(strptime(as.matrix(phenology[, 5:13]),"%Y-%m-%d")$year +
                                        1900),
                                  na.rm = TRUE)
  phenology_header[10,1] = sprintf("# Creation Date: %s", Sys.Date())
  phenology_header[11,1] = sprintf("# Creation Time: %s", format(Sys.time(), "%H:%M:%S"))
  
  return(list(plot_data, spring, fall, phenology_header))
}

# test = get_site_roi_csvs('acadia', roi_files, frequency_ = 3, metrics_ = c('gcc_90'), percentile_ = 90, roi_type_ = 'DB')
# test = get_site_roi_csvs('arbutuslakeinlet', roi_files, frequency_ = 1, metrics_ = c('gcc_90'), percentile_ = 90, roi_type_ = 'EN')
# test = get_site_roi_csvs('arbutuslakeinlet', roi_files, frequency_ = 3, metrics_ = c('gcc_90'), percentile_ = 90, roi_type_ = 'DB')




# Smoothes ndvi, evi or gccc data  (uses the optimal span function)
smooth_ts = function(data,
                     metrics = c("gcc_mean",
                                 "gcc_50",
                                 "gcc_75",
                                 "gcc_90",
                                 "rcc_mean",
                                 "rcc_50",
                                 "rcc_75",
                                 "rcc_90"),
                     force = TRUE, frequency) {
  
  
  
  # split out data from read in or provided data
  df = data
  
  # maximum allowed gap before the whole stretch is
  # flagged as too long to be reliably interpolated
  maxgap = 14
  
  # create convenient date vector
  # (static for all data)
  dates = as.Date(df$date)
  
  # create output matrix
  output = matrix(NA, length(dates), length(metrics) * 2 + 1)
  output = as.data.frame(output)
  column_names = c(sprintf("smooth_%s", metrics),
                   sprintf("smooth_ci_%s", metrics),
                   "int_flag")
  colnames(output) = column_names
  
  # loop over all metrics that need smoothing
  for (i in metrics) {
    
    # get the values to use for smoothing
    v=is.element(colnames(df), i)
    values = df[, ..v]
    
    # flag all outliers as NA
    # if the metric is gcc based
    if (grepl("gcc", i)) {
      outliers = df[, which(colnames(df) == sprintf("outlierflag_%s", i))]
      values[outliers == 1] = NA
    }
    
    # create yearly mean values and fill in time series
    # with those, keep track of which values are filled
    # using the int_flag data
    nr_years = length(unique(df$year))
    
    # find the location of the original NA values
    # to use to fill these gaps later
    na_orig = which(is.na(values))
    
    # na locations (default locations for 3-day product)
    # this to prevent inflation of the number of true
    # values in the 3-day product
    loc = seq(2,366,3)
    loc = (df$doy %in% loc)
    
    # Calculate the locations of long NA gaps.
    # (find remaining NA values after interpolation,
    # limited to 2 weeks in time)
    long_na = which(is.na(zoo::na.approx(
      values, maxgap = maxgap, na.rm = FALSE
    )))
    
    # also find the short gaps (inverse long gaps)
    # to smooth spikes
    short_na = which(!is.na(zoo::na.approx(
      values, maxgap = maxgap, na.rm = FALSE
    )))
    short_na = which(short_na %in% is.na(values))
    
    # this routine takes care of gap filling large gaps
    # using priors derived from averaging values across
    # years or linearly interpolating. The averaging over
    # years is needed to limit artifacts at the beginning
    # and end of cycles in subsequent phenophase extraction
    if (nr_years >= 2) {
      
      # used to be 3, fill values using those of the remaining year
      
      # calculate the mean values for locations
      # where there are no values across years
      fill_values = by(values,INDICES = df$doy, mean, na.rm = TRUE)
      doy_fill_values = as.numeric(names(fill_values))
      #doy_na = df$doy[na_orig]
      doy_na = df$doy[long_na]
      
      # calculate the interpolated data based on
      # the whole dataset
      int_data = unlist(lapply(doy_na,
                               function(x,...) {
                                 fv = fill_values[which(doy_fill_values == x)]
                                 if (length(fv) == 0) {
                                   return(NA)
                                 }else{
                                   return(fv)
                                 }
                               }))
      
      # gap fill the original dataset using
      # the interpolated values
      gap_filled_prior = values
      #gap_filled_prior[na_orig] = int_data
      gap_filled_prior[long_na] = int_data
      
      # reset NA short sections to NA and interpolate these linearly
      # only long NA periods merit using priors
      gap_filled_prior[short_na] = NA
      gap_filled_linear = zoo::na.approx(gap_filled_prior, na.rm = FALSE)
      
      # the above value should be independent of the ones used in the carry
      # forward / backward exercise
      
      # traps values stuck at the end in NA mode, use carry
      # forward and backward to fill these in! These errors
      # don't pop up when using a fitting model (see above)
      gap_filled_forward = zoo::na.locf(gap_filled_linear,
                                        na.rm = FALSE)
      gap_filled_backward = zoo::na.locf(gap_filled_linear,
                                         na.rm = FALSE,
                                         fromLast = TRUE)
      
      # drop in values at remaining NA places
      gap_filled_forward[is.na(gap_filled_forward)] = gap_filled_backward[is.na(gap_filled_forward)]
      gap_filled_backward[is.na(gap_filled_backward)] = gap_filled_forward[is.na(gap_filled_backward)]
      
      # take the mean of the carry forward and backward run
      # this should counter some high or low biases by using the
      # average of last or first value before or after an NA stretch
      gap_filled_linear = ( gap_filled_forward + gap_filled_backward ) / 2
      gap_filled = apply(cbind(gap_filled_prior,gap_filled_linear),1,max,na.rm=TRUE)
      
    }else{
      
      # for short series, where averaging over years isn't possible
      # linearly interpolate the data for gap filling
      # it's not ideal (no priors) but the best you have
      gap_filled = zoo::na.approx(values, na.rm = FALSE)
      
      # traps values stuck at the end in NA mode, use carry
      # forward and backward to fill these in! These errors
      # don't pop up when using a fitting model (see above)
      gap_filled = zoo::na.locf(gap_filled, na.rm = FALSE)
      gap_filled = zoo::na.locf(gap_filled, na.rm = FALSE, fromLast = TRUE)
    }
    
    # the gap_filled object is used in the subsequent analysis
    # to calculate the ideal fit, down weighing those areas
    # which were interpolated
    
    # create weight vector for original NA
    # values and snow flag data
    weights = rep(1,nrow(values))
    weights[na_orig] = 0.001
    #weights[df$snow_flag == 1] = 0.001
    
    # smooth input series for plotting
    # set locations to NA which would otherwise not exist in the
    # 3-day product, as not to inflate the number of measurements
    if (frequency == 3){
      
      optim_span = suppressWarnings(
        optimal_span(x = as.numeric(dates[loc]),
                     y = gap_filled[loc],
                     plot = FALSE))
      
      fit = suppressWarnings(
        stats::loess(gap_filled[loc] ~ as.numeric(dates[loc]),
                     span = optim_span,
                     weights = weights[loc]))
      
    } else { # 1-day product
      
      optim_span = suppressWarnings(
        optimal_span(x = as.numeric(dates),
                     y = gap_filled,
                     plot = FALSE))
      
      fit = suppressWarnings(
        stats::loess(gap_filled ~ as.numeric(dates),
                     span = optim_span,
                     weights = weights))
      
    }
    
    # make projections based upon the optimal fit
    fit = suppressWarnings(stats::predict(fit, as.numeric(dates), se = TRUE))
    
    # grab the smoothed series and the CI (from SE)
    # set to 0 if no SE is provided
    values_smooth = fit$fit
    
    # calculate the CI (from SE)
    values_ci = 1.96 * fit$se
    
    # cap CI values to 0.02
    values_ci[values_ci > 0.02] = 0.02
    
    # trap trailing and starting NA values
    values_smooth = zoo::na.locf(values_smooth,
                                 na.rm=FALSE)
    values_smooth = zoo::na.locf(values_smooth,
                                 fromLast = TRUE,
                                 na.rm=FALSE)
    
    # set values for long interpolated values to 0
    # these are effectively missing or inaccurate
    # (consider setting those to NA, although this
    # might mess up plotting routines)
    values_ci[long_na] = 0.02
    
    # trap values where no CI was calculated and
    # assign the fixed value
    values_ci[is.nan(fit$se)] = 0.02
    values_ci[is.na(fit$se)] = 0.02
    values_ci[is.infinite(fit$se)] = 0.02
    
    # set values to NA if interpolated
    # max gap is 'maxgap' days, to avoid flagging periods where
    # you only lack some data
    # this is redundant should only do this once (fix)
    int = zoo::na.approx(values, maxgap = maxgap, na.rm = FALSE)
    
    # put everything in the output matrix
    output$int_flag[which(is.na(int))] = 1
    output[, which(colnames(output) == sprintf("smooth_%s", i))] = round(values_smooth,5)
    output[, which(colnames(output) == sprintf("smooth_ci_%s", i))] = round(values_ci,5)
    
    cols = rep("red",length(gap_filled))
    cols[long_na] = "green"
  }
  
  # drop previously smoothed data from
  # a data frame
  # dropvar = is.element(names(df), column_names)  #maybe break here
  # df = df[,!dropvar]
  df = cbind(df, output)
  
  # put data back into the data structure
  data= df
  
  # write the data to the original data frame or the
  # original file (overwrites the data!!!)
  
  return(data) #data,
}










# Calculates optimal span for smooth
optimal_span = function(y,
                        x = NULL,
                        weights = NULL,
                        step = 0.01,
                        label = NULL,
                        plot = FALSE){
  
  # custom AIC function which accepts loess regressions
  myAIC = function(x){
    
    if (!(inherits(x, "loess"))){
      stop("Error: argument must be a loess object")
    }
    
    # extract loess object parameters
    n = x$n
    traceL = x$trace.hat
    sigma2 = sum( x$residuals^2 ) / (n-1)
    delta1 = x$one.delta
    delta2 = x$two.delta
    enp = x$enp
    
    # calculate AICc1
    # as formulated by Clifford M. Hurvich; Jeffrey S. Simonoff; Chih-Ling Tsai (1998)
    AICc1 = n*log(sigma2) + n* ( (delta1/delta2)*(n+enp) / ((delta1^2/delta2)-2))
    
    if(is.na(AICc1) | is.infinite(AICc1)){
      return(NA)
    }else{
      return(AICc1)
    }
  }
  
  # create numerator if there is none
  if (is.null(x)){
    x = 1:length(y)
  }
  
  # return AIC for a loess function with a given span
  loessAIC = function(span){
    # check if there are weights, if so use them
    if ( is.null(weights) ){
      fit = suppressWarnings(try(stats::loess(y ~ as.numeric(x),
                                              span = span),
                                 silent = TRUE))
    } else {
      fit = suppressWarnings(try(stats::loess(y ~ as.numeric(x),
                                              span = span,
                                              weights = weights),
                                 silent = TRUE))
    }
    
    # check if the fit failed if so return NA
    if (inherits(fit, "try-error")){
      return(NA)
    }else{
      return(myAIC(fit))
    }
  }
  
  # parameter range
  span = seq(0.01, 1, by = step)
  
  # temporary AIC matrix, lapply loop
  # (instead of for loop) cleaner syntax
  tmp = unlist(lapply(span, loessAIC))
  
  # find the optimal span as the minimal AICc1 value
  # in the calculated range (span variable)
  opt_span = span[which(tmp == min(tmp, na.rm = TRUE))][1]
  
  # plot the optimization if requested
  if (plot == TRUE){
    
    graphics::par(mfrow = c(2,1))
    plot(as.numeric(x),y,
         xlab = 'value',
         ylab = 'Gcc',
         type = 'p',
         pch = 19,
         main = label)
    
    col = grDevices::rainbow(length(span),alpha = 0.5)
    
    for (i in 1:length(span)){
      fit = stats::loess(y ~ as.numeric(x),
                         span = span[i])
      graphics::lines(fit$x,
                      fit$fitted,
                      lwd = 1,
                      col = col[i])
    }
    
    fit = stats::loess(y ~ as.numeric(x),
                       span = opt_span)
    
    graphics::lines(fit$x,
                    fit$fitted,
                    lwd = 3,
                    col = 'black',
                    lty = 1)
    
    plot(span,
         tmp,
         pch = 19,
         type = 'p',
         ylab = 'AICc1',
         col = col)
    
    graphics::abline(v = opt_span,col = 'black')
    
  }
  
  # trap error and return optimal span
  if (is.na(opt_span)) {
    return(NULL)
  } else {
    return(opt_span)
  }
}