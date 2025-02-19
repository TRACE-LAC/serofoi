#' Sets normal distribution parameters for sampling
#'
#' @param mean Mean of the normal distribution
#' @param sd Standard deviation of the normal distribution
#' @return List with specified statistics and name of the model
#' @examples
#' my_prior <- sf_normal()
#' @export
sf_normal <- function(mean = 0, sd = 1) {
  # Restricting normal inputs to be non-negative
  if (mean < 0 || sd <= 0) {
    stop(
      "Normal distribution only accepts",
      " `mean>=0` and `sd>0` for mean and standard deviation",
      call. = FALSE
    )
  }

  return(list(mean = mean, sd = sd, name = "normal"))
}

#' Sets uniform distribution parameters for sampling
#'
#' @param min Minimum value of the random variable of the uniform distribution
#' @param max Maximum value of the random variable of the uniform distribution
#' @return List with specified statistics and name of the model
#' @examples
#' my_prior <- sf_uniform()
#' @export
sf_uniform <- function(min = 0, max = 10) {
  # Restricting uniform inputs to be non-negative
  if (min < 0 || (min >= max)) {
    stop(
      "Uniform distribution only accepts",
      " 0<=min<max",
      call. = FALSE
    )
  }

  return(list(min = min, max = max, name = "uniform"))
}

#' Sets Cauchy distribution parameters for sampling
#'
#' @param location Location of the Cauchy distribution
#' @param scale Scale of the Cauchy distribution
#' @return List with specified statistics and name of the distribution
#' @examples
#' my_prior <- sf_cauchy()
#' @export
sf_cauchy <- function(location = 0, scale = 1) {
  if (location < 0 || scale < 0) { # Restricting inputs to be non-negative
    stop(
      "Cauchy distribution only accepts",
      " `location>=0` and `scale>=0` for median and median absolute deviation",
      call. = FALSE)
  }

  return(list(location = location, scale = scale, name = "cauchy"))
}

#' Sets empty prior distribution
#'
#' @return List with the name of the empty distribution
#' @export
sf_none <- function() {
  list(name = "none")
}

#' Generates Force-of-Infection indexes for heterogeneous age groups
#'
#' Generates a list of integers indexing together the time/age intervals
#' for which FoI values will be estimated in [fit_seromodel].
#' The max value in `foi_index`  corresponds to the number of FoI values to
#' be estimated when sampling.
#' The serofoi approach to fitting serological data currently supposes that FoI
#' is piecewise-constant across either groups of years or ages, and this
#' function creates a Data Frame that communicates this grouping to the
#' Stan model
#' @inheritParams fit_seromodel
#' @param group_size Age groups size
#' @param model_type Type of the model. Either "age" or "time"
#' @return A Data Frame which describes the grouping of years or ages
#' (dependent on model) into pieces within which the FoI is assumed constant
#' when performing model fitting. A single FoI value will be estimated for
#' ages/years assigned with the same index
#' @examples
#' data(chagas2012)
#' foi_index <- get_foi_index(chagas2012, group_size = 25, model_type = "time")
#' @export
get_foi_index <- function(
  serosurvey,
  group_size,
  model_type
  ) {
  # Check model_type correspond to a valid model
  stopifnot(
    "model_type must be either 'time' or 'age'" =
    model_type %in% c("time", "age")
  )

  # Check group_size dimension is in the right range
  checkmate::assert_int(
    group_size,
    lower = 1,
    upper = max(serosurvey$age_max)
    )

  foi_indexes <- unlist(
    purrr::map(
      seq(
        1,
        max(serosurvey$age_max) / group_size,
        1),
      rep,
      times = group_size
    )
  )

  foi_indexes <- c(
    foi_indexes,
    rep(
      max(foi_indexes),
      max(serosurvey$age_max) - length(foi_indexes)
    )
  )

  if (model_type == "time") {
    survey_year <- unique(serosurvey$survey_year)
    foi_index <- data.frame(
      year = seq(survey_year - max(serosurvey$age_max), survey_year - 1),
      foi_index = foi_indexes
    )
  } else if (model_type == "age") {
    foi_index <- data.frame(
      age = seq(1, max(serosurvey$age_max), 1),
      foi_index = foi_indexes
    )
  }

  foi_index
}

#' Set stan data defaults for sampling
#'
#' @param stan_data List to be passed to [rstan][rstan::sampling]
#' @inheritParams fit_seromodel
#' @return List with default values of stan data for sampling
#' @export
set_stan_data_defaults <- function(
    stan_data,
    is_log_foi = FALSE,
    is_seroreversion = FALSE
) {
  config_file <- system.file("extdata", "config.yml", package = "serofoi")
  prior_default <- config::get(file = config_file, "priors")$defaults

  foi_defaults <- list(
    foi_prior_index = prior_default$index,
    foi_min = prior_default$min,
    foi_max = prior_default$max,
    foi_mean = prior_default$mean,
    foi_sd = prior_default$sd
  )
  # Add sigma defaults depending on scale
  if (is_log_foi) {
    # Normal distribution defaults
    foi_defaults <- c(
      foi_defaults,
      list(
        foi_sigma_rw_loc = prior_default$mean,
        foi_sigma_rw_sc = prior_default$sd
      )
    )
  } else {
    # Cauchy distribution defaults
    foi_defaults <- c(
      foi_defaults,
      list(
        foi_sigma_rw_loc = prior_default$location,
        foi_sigma_rw_sc = prior_default$scale
      )
    )
  }
  stan_data <- c(
    stan_data,
    foi_defaults
  )

  if (is_seroreversion) {
    seroreversion_defaults <- list(
      seroreversion_prior_index = prior_default$index,
      seroreversion_min = prior_default$min,
      seroreversion_max = prior_default$max,
      seroreversion_mean = prior_default$mean,
      seroreversion_sd = prior_default$sd
    )
    stan_data <- c(
      stan_data,
      seroreversion_defaults
    )
  }

  return(stan_data)
}

#' Builds stan data for sampling depending on the selected model
#'
#' @inheritParams fit_seromodel
#' @return List with necessary data for sampling the specified model
#' @export
build_stan_data <- function(
    serosurvey,
    model_type = "constant",
    foi_prior = sf_uniform(),
    foi_index = NULL,
    is_log_foi = FALSE,
    foi_sigma_rw = sf_none(),
    is_seroreversion = FALSE,
    seroreversion_prior = sf_none()
) {

  stan_data <- list(
    n_observations = nrow(serosurvey),
    age_max = max(serosurvey$age_max),
    ages = seq(1, max(serosurvey$age_max), 1),
    n_seropositive = serosurvey$n_seropositive,
    n_sample = serosurvey$n_sample,
    age_groups = serosurvey$age_group
  ) |>
    set_stan_data_defaults(
      is_log_foi = is_log_foi,
      is_seroreversion = is_seroreversion
    )

  if (model_type == "constant") {
    stan_data <- c(
      stan_data,
      list(foi_index = rep(1, max(serosurvey$age_max)))
    )
  } else if (is.null(foi_index) && model_type != "constant") {
    foi_index_default <- get_foi_index(
      serosurvey = serosurvey,
      group_size = 1,
      model_type = model_type
    ) |>
    validate_foi_index(
      serosurvey = serosurvey,
      model_type = model_type
    )

    stan_data <- c(
      stan_data,
      list(foi_index = foi_index_default$foi_index)
    )
  } else {
    validate_foi_index(
      foi_index = foi_index,
      serosurvey = serosurvey,
      model_type = model_type
    )

    stan_data <- c(
      stan_data,
      list(foi_index = foi_index$foi_index)
    )
  }
  config_file <- system.file("extdata", "config.yml", package = "serofoi")
  prior_index <- config::get(file = config_file, "priors")$indexes

  if (foi_prior$name == "uniform") {
    stan_data$foi_prior_index <- prior_index[["uniform"]]
    stan_data$foi_min <- foi_prior$min
    stan_data$foi_max <- foi_prior$max
  } else if (foi_prior$name == "normal") {
    stan_data$foi_prior_index <- prior_index[["normal"]]
    stan_data$foi_mean <- foi_prior$mean
    stan_data$foi_sd <- foi_prior$sd
  }

  if (foi_sigma_rw$name == "cauchy") {
    stan_data$foi_sigma_rw_loc <- foi_sigma_rw$location
    stan_data$foi_sigma_rw_sc <- foi_sigma_rw$scale
  }

  if (is_seroreversion) {
    if (seroreversion_prior$name == "none") {
      stop("seroreversion_prior not specified", call. = FALSE)
    }

    stan_data$seroreversion_prior_index <- switch(
      seroreversion_prior$name,
      uniform = prior_index[["uniform"]],
      normal = prior_index[["normal"]],
      stop("Invalid seroreversion_prior name", call. = FALSE) # Default case
    )

    switch(
      seroreversion_prior$name,
      uniform = {
        stan_data$seroreversion_min <- seroreversion_prior$min
        stan_data$seroreversion_max <- seroreversion_prior$max
      },
      normal = {
        stan_data$seroreversion_mean <- seroreversion_prior$mean
        stan_data$seroreversion_sd <- seroreversion_prior$sd
      }
    )
  }

  return(stan_data)
}
