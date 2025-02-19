#' Helper function to validate serosurvey structure
#'
#' @keywords internal
validate_serosurvey <- function(serosurvey) {
  # Check that necessary columns are present
  col_types <- list(
    age_min = "numeric",
    age_max = "numeric",
    n_sample = "numeric",
    n_seropositive = "numeric"
  )

  checkmate::assert_names(names(serosurvey), must.include = names(col_types))

  # Validates column types
  error_messages <- list()
  for (col in names(col_types)) {
    valid_col_types <- as.list(col_types[[col]])

    # Only validates column type if the column exists in the dataframe
    if (col %in% colnames(serosurvey) &&
        !any(vapply(valid_col_types, function(type) {
          do.call(sprintf("is.%s", type), list(serosurvey[[col]]))
        }, logical(1)))) {
      error_messages <- c(
        error_messages,
        sprintf(
          "`%s` must be of any of these types: `%s`",
          col, toString(col_types[[col]])
        )
      )
    }
  }
  if (length(error_messages) > 0) {
    stop(
      "The following columns in `serosurvey` have wrong types:\n",
      toString(error_messages),
      call. = FALSE
    )
  }

  serosurvey
}

#' Check min and max age consistency for validation purposes
#'
#' @return Boolean checking consistency
#' @keywords internal
check_age_constraints <- function(df) {
  for (i in seq_len(nrow(df))) {
    for (j in seq_len(nrow(df))) {
      if (i != j && df$age_max[i] == df$age_min[j]) {
        return(FALSE)
      }
    }
  }

  TRUE
}

#' Helper function to validate serosurvey features for simulation
#'
#' @return None
#' @keywords internal
validate_survey_features <- function(survey_features) {

  if (!is.data.frame(survey_features) ||
      !all(
        c("age_min", "age_max", "n_sample") %in% names(survey_features))
      ) {
    stop(
      "survey_features must be a dataframe with columns ",
      "'age_min', 'age_max', and 'n_sample'.",
      call. = FALSE
      )
  }

  # check that the age_max of a bin does not coincide with
  # the age min of a different bin
  is_age_ok <- check_age_constraints(survey_features)
  if (!is_age_ok)
    stop(
      "Age bins in a survey are inclusive of both bounds, ",
      "so the age_max of one bin cannot equal the age_min of another.",
      call. = FALSE
      )
}

#' Helper function to validate FoI structure for simulation
#'
#' @return None
#' @keywords internal
validate_foi_df <- function(foi_df, cnames_additional) {
  if (
    !is.data.frame(foi_df) ||
    !all(cnames_additional %in% names(foi_df)) ||
    ncol(foi_df) != (1 + length(cnames_additional))
    ) {
    if (length(cnames_additional) == 1) {
      message_end <- paste0(" and ", cnames_additional, ".")
    } else {
      message_end <- paste0(
        ", ", paste(cnames_additional, collapse = " and "), "."
        )
    }
    message_beginning <- "foi must be a dataframe with columns foi"
    stop(glue::glue("{message_beginning}", "{message_end}"), call. = FALSE)
  }
}

#' Helper function to validate seroreversion rate properties for simulation
#'
#' @return None
#' @keywords internal
validate_seroreversion_rate <- function(seroreversion_rate) {
  if (!is.numeric(seroreversion_rate) || seroreversion_rate < 0) {
    stop(
      "seroreversion_rate must be a non-negative numeric value.",
      call. = FALSE)
  }
}

#' Helper function to validate consistency between the FoI and the survey
#' features for simulation
#'
#' @return None
#' @keywords internal
validate_simulation_age <- function(
    survey_features,
    foi_df
) {
  max_age_foi_df <- nrow(foi_df)
  if (max_age_foi_df > max(survey_features$age_max))
    stop(
      "maximum age implicit in foi_df should ",
      "not exceed max age in survey_features.",
      call. = FALSE
      )
}

#' Helper function to validate consistency between the FoI and the survey
#' features for simulation of age- and time-varying model
#'
#' @return None
#' @keywords internal
validate_simulation_age_time <- function(
    survey_features,
    foi_df
) {
  max_age_foi_df <- max(foi_df$year) - min(foi_df$year) + 1
  if (max_age_foi_df > max(survey_features$age_max))
    stop(
      "maximum age implicit in foi_df should ",
      "not exceed max age in survey_features.",
      call. = FALSE
      )
}

#' Helper function to validate FoI index consistency
#'
#' @return foi_index
#' @keywords internal
validate_foi_index <- function(
  foi_index,
  serosurvey,
  model_type
) {
  # Check model_type correspond to a valid model
  stopifnot(
    "model_type must be either 'time' or 'age'" =
    model_type %in% c("time", "age")
  )

  # validate that foi_index has the right columns
  if (model_type == "age") {
    checkmate::assert_names(names(foi_index), must.include = "age")
  } else if (model_type == "time") {
    checkmate::assert_names(names(foi_index), must.include = "year")
  }

  # Check that foi_index has the right properties
  stopifnot(
    # validate that foi_index has the right size
    "foi_index must be the right size" =
    nrow(foi_index) == max(serosurvey$age_max),
    # validate that foi_index contains consecutive indexes
    "foi_index$foi_index must contain consecutive indexes" =
    # 0 validates that indexes do not decrease for consecutive chunks
    # 1 validates that there are not missing indexes
    diff(foi_index$foi_index) %in% c(0, 1)
  )

  foi_index
}

#' Helper function to validate whether the current plot corresponds
#' to a constant model
#'
#' @return TRUE
#' @keywords internal
validate_plot_constant <- function(
    plot_constant,
    x_axis,
    model_name,
    error_msg_x_axis
) {
  if (plot_constant) {
    if (!startsWith(model_name, "constant")) {
      error_msg <- paste0(
        "plot_constant is only relevant when ",
        "`seromodel@model_name == 'constant'`"
      )
      stop(error_msg, call. = FALSE)
    }
    if (!(x_axis %in% c("age", "time"))) {
      stop(error_msg_x_axis, call. = FALSE)
    }
  }

  TRUE
}
