#' @title Prepare data for machine learning
#'
#' @description \code{prep_data} will prepare your data for use with
#'   \code{\link{tune_models}} or other machine learning packages. Data can be
#'   transformed in the following ways: \enumerate{ \item{Convert columns with
#'   only 0/1 to factor} \item{Remove columns with near-zero variance}
#'   \item{Convert date columns to useful features} \item{Fill in missing values
#'   with various imputation methods} \item{Collapse rare categories into
#'   `other`} \item{Center numeric columns} \item{Standardize numeric columns}
#'   \item{Create dummy variables} \item{Add levels to factors for rare and
#'   missing data}} While preparing your data, a recipe will be generated for
#'   identical transformation of future data and stored in the `recipe`
#'   attribute of the output data frame. If a recipe object is passed to
#'   `prep_data` via the `recipe` argument, that recipe will be applied to the
#'   data. This allows you to transform data in model training and apply exactly
#'   the same transformations in model testing and deployment. The new data must
#'   be identical in structure to the data that the recipe was prepared with.
#'
#' @param d A dataframe or tibble containing data to impute.
#' @param ... Optional. Unquoted variable names to not be prepped. These will be
#'   returned unaltered. Typically ID and outcome columns would go here.
#' @param outcome Optional. Unquoted column name that indicates the target
#'   variable. If provided, argument must be named. If this target is 0/1, it
#'   will be coerced to Y/N if factor_outcome is TRUE; other manipulation steps
#'   will not be applied to the outcome.
#' @param recipe Optional. Recipe for how to prep d. In model deployment, pass
#'   the output from this function in training to this argument in deployment to
#'   prepare the deployment data identically to how the training data was
#'   prepared. If training data is big, pull the recipe from the "recipe"
#'   attribute of the prepped training data frame and pass that to this
#'   argument. If present, all following arguments will be ignored.
#' @param remove_near_zero_variance Logical. If TRUE (default), columns with
#'   near-zero variance will be removed. These columns are either a single
#'   value, or meet both of the following criteria: 1. they have very few unique
#'   values relative to the number of samples and 2. the ratio of the frequency
#'   of the most common value to the frequency of the second most common value
#'   is large.
#' @param convert_dates Logical or character. If TRUE (default), date columns
#'   are identifed and used to generate day-of-week, month, and year columns,
#'   and the original date columns are removed. If FALSE, date columns are
#'   removed. If a character vector, it is passed to the `features` argument of
#'   `recipes::step_date`. E.g. if you want only quarter and year back:
#'   `convert_dates = c("quarter", "year")`.
#' @param impute Logical or list. If TRUE (default), columns will be imputed
#'   using mean (numeric), and new category (nominal). If FALSE, data will not
#'   be imputed. If this is a list, it must be named, with possible entries for
#'   `numeric_method`, `nominal_method`, `numeric_params`, `nominal_params`,
#'   which are passed to \code{\link{hcai_impute}}.
#' @param collapse_rare_factors Logical or numeric. If TRUE (default), factor
#'   levels representing less than 3 percent of observations will be collapsed
#'   into a new category, `other`. If numeric, must be in {0, 1}, and is the
#'   proportion of observations below which levels will be grouped into other.
#'   See `recipes::step_other`.
#' @param center Logical. If TRUE, numeric columns will be centered to have a
#'   mean of 0. Default is FALSE.
#' @param scale Logical. If TRUE, numeric columns will be scaled to have a
#'   standard deviation of 1. Default is FALSE.
#' @param make_dummies Logical. If TRUE (default), dummy columns will be created
#'   for categorical variables.
#' @param add_levels Logical. If TRUE (defaults), "other" and "hcai_missing"
#'   will be added to all nominal columns. This is protective in deployment: new
#'   levels found in deployment will become "other" and missingness in
#'   deployment can become "hcai_missing".
#' @param factor_outcome Logical. If TRUE (default) and if all entries in
#'   outcome are 0 or 1 they will be converted to factor with levels N and Y for
#'   classification.
#'
#' @return Prepared data frame with reusable recipe object for future data
#'   preparation in attribute "recipe". Attribute recipe contains the names of
#'   ignored columns (those passed to ...) in attribute "ignored_columns".
#' @export
#' @seealso \code{\link{hcai_impute}}, \code{\link{tune_models}},
#'   \code{\link{predict.model_list}}
#'
#' @examples
#' d_train <- pima_diabetes[1:700, ]
#' d_test <- pima_diabetes[701:768, ]
#'
#' # Prep data. Ignore patient_id (identifier) and treat diabetes as outcome
#' d_train_prepped <- prep_data(d = d_train, patient_id, outcome = diabetes)
#'
#' # Prep test data by reapplying the same transformations as to training data
#' d_test_prepped <- prep_data(d_test, recipe = d_train_prepped)
#'
#' # View the transformations applied and the prepped data
#' d_test_prepped
#'
#' # Customize preparations:
#' prep_data(d = d_train, patient_id, diabetes,
#'           impute = list(numeric_method = "bagimpute",
#'                         nominal_method = "bagimpute"),
#'           collapse_rare_factors = FALSE, convert_dates = "year",
#'           center = TRUE, scale = TRUE, make_dummies = FALSE)
prep_data <- function(d,
                      ...,
                      outcome,
                      recipe = NULL,
                      remove_near_zero_variance = TRUE,
                      convert_dates = TRUE,
                      impute = TRUE,
                      collapse_rare_factors = TRUE,
                      center = FALSE,
                      scale = FALSE,
                      make_dummies = TRUE,
                      add_levels = TRUE,
                      factor_outcome = TRUE) {
  # Check to make sure that d is a dframe
  if (!is.data.frame(d)) {
    stop("\"d\" must be a data frame.")
  }
  # Deal with "..." columns to be ignored
  ignore_columns <- rlang::quos(...)
  ignored <- purrr::map_chr(ignore_columns, rlang::quo_name)
  d_ignore <- NULL
  if (length(ignore_columns)) {
    present <- ignored %in% names(d)
    if (any(!present))
      stop(paste(ignored[!present], collapse = ", "), " not found in d.")
    # Separate data into ignored and not
    d_ignore <- dplyr::select(d, !!ignored)
    d <- dplyr::select(d, -dplyr::one_of(ignored))
    # Warn if ignored columns have missingness
    m <- missingness(d_ignore) %>%
      dplyr::filter(percent_missing > 0)
    if (!purrr::is_empty(m$variable))
      warning("These ignored variables have missingness: ",
              paste(m$variable, collapse = ", "))
  }

  # If there's a recipe in recipe, use that
  if (!is.null(recipe)) {
    message("Prepping data based on provided recipe")
    recipe <- check_rec_obj(recipe)
    # Look for variables that weren't present in training, add them to ignored
    newvars <- setdiff(names(d), c(recipe$var_info$variable,
                                   attr(recipe, "ignored_columns")))
    if (length(newvars)) {
      warning("These variables were not observed in training ",
              "and will be ignored: ", paste(newvars, collapse = ", "))
      ignored <- c(ignored, newvars)
      d_ignore <- dplyr::bind_cols(d_ignore, dplyr::select(d, !!newvars))
    }
    # Look for predictors unignored in training but missing here and error
    missing_vars <- setdiff(recipe$var_info$variable[recipe$var_info$role == "predictor"], names(d))
    if (length(missing_vars))
      stop("These variables were present in training but are missing or ignored here: ",
           paste(missing_vars, collapse = ", "))
  } else {

    # Initialize a new recipe
    message("Training new data prep recipe")
    ## Start by making all variables predictors...
    recipe <- recipes::recipe(d, ~ .)
    ## Then deal with outcome if present
    outcome <- rlang::enquo(outcome)
    if (!rlang::quo_is_missing(outcome)) {
      outcome_name <- rlang::quo_name(outcome)
      if (!outcome_name %in% names(d))
        stop(paste(outcome_name, " not found in d."))
      # Check if there are NAs in the target
      outcome_vec <- dplyr::pull(d, !!outcome)
      # Currently can't deal with logical outcomes
      if (is.logical(outcome_vec) || any(c("TRUE", "FALSE") %in% outcome_vec))
        stop("outcome looks logical. Please convert the outcome to character",
             " with values other than TRUE and FALSE.")
      if (any(is.na(outcome_vec)))
        stop("Found NA values in the outcome column. Clean your data or ",
             "remove these rows before training a model.")
      # Changing the role of outcome from predictor to outcome warns, shush:
      suppressWarnings({
        recipe <- recipes::add_role(recipe, !!outcome, new_role = "outcome")
      })

      # If outcome is binary 0/1, convert to N/Y -----------------------------
      if (factor_outcome && all(outcome_vec %in% 0:1)) {
        recipe <- recipe %>%
          recipes::step_bin2factor(all_outcomes(), levels = c("Y", "N"))
      }
    }

    # Build recipe step-by-step:

    # TODO
    # Find largely missing columns and convert to factors
    # recipe <- recipe %>% step_hcai_mostly_missing_to_factor()  # nolint

    # Remove columns with near zero variance ----------------------------------
    if (remove_near_zero_variance) {
      recipe <- recipe %>%
        recipes::step_nzv(all_predictors())
    }

    # Convert date columns to useful features and remove original. ------------
    if (!is.logical(convert_dates)) {
      if (!is.character(convert_dates))  #  || is.null(names(convert_date))
        stop("convert_dates must be logical or features for step_date")
      sdf <- convert_dates
      convert_dates <- TRUE
    }
    if (convert_dates) {
      # If user didn't provide features, set them to defaults
      if (!exists("sdf"))
        sdf <- c("dow", "month", "year")
      cols <- find_date_cols(d)
      if (!purrr::is_empty(cols)) {
        recipe <-
          do.call(recipes::step_date,
                  list(recipe = recipe, cols, features = sdf)) %>%
          recipes::step_rm(cols)
      }
    } else {
      cols <- find_date_cols(d)
      if (!purrr::is_empty(cols))
        recipe <- recipes::step_rm(recipe, cols)
    }

    # Impute ------------------------------------------------------------------
    if (isTRUE(impute)) {
      recipe <- recipe %>%
        hcai_impute()
    } else if (is.list(impute)) {
      # Set defaults
      ip <- list(numeric_method = "mean",
                 nominal_method = "new_category",
                 numeric_params = NULL,
                 nominal_params = NULL)
      ip[names(ip) %in% names(impute)] <- impute[names(impute) %in% names(ip)]
      extras  <- names(impute)[!(names(impute) %in% names(ip))]
      if (length(extras > 0)) {
        warning("You have extra imputation parameters that won't be used: ",
                paste(extras, collapse = ", "),
                ". Available params are: ", paste(names(ip), collapse = ", "))
      }

      # Impute takes defaults or user specified inputs. Error handling inside.
      recipe <- recipe %>%
        hcai_impute(numeric_method = ip$numeric_method,
                    nominal_method = ip$nominal_method,
                    numeric_params = ip$numeric_params,
                    nominal_params = ip$nominal_params)
    } else if (impute != FALSE) {
      stop("impute must be boolean or list.")
    }

    # If there are numeric predictors, apply numeric transformations
    var_info <- recipe$var_info
    if (any(var_info$type == "numeric" & var_info$role == "predictor")) {

      # Log transform
      # Saving until columns can be specified

      # Center ------------------------------------------------------------------
      if (center) {
        recipe <- recipe %>%
          recipes::step_center(all_numeric(), - all_outcomes())
      }

      # Scale -------------------------------------------------------------------
      if (scale) {
        recipe <- recipe %>%
          recipes::step_scale(all_numeric(), - all_outcomes())
      }
    }

    # If there are nominal predictors, apply nominal transformations
    if (any(var_info$type == "nominal" & var_info$role == "predictor")) {
      # Collapse rare factors into "other" --------------------------------------
      if (!is.logical(collapse_rare_factors)) {
        if (!is.numeric(collapse_rare_factors))
          stop("collapse_rare_factors must be logical or numeric")
        if (collapse_rare_factors >= 1 || collapse_rare_factors < 0)
          stop("If numeric, collapse_rare_factors should be between 0 and 1.")
        fac_thresh <- collapse_rare_factors
        collapse_rare_factors <- TRUE
      }
      if (collapse_rare_factors) {
        if (!exists("fac_thresh"))
          fac_thresh <- 0.03
        recipe <- recipe %>%
          recipes::step_other(all_nominal(), - all_outcomes(),
                              threshold = fac_thresh)
      }

      # Add protective levels --------------------------------------------------
      if (add_levels)
        recipe <- step_add_levels(recipe, all_nominal(), - all_outcomes())

      # make_dummies -----------------------------------------------------------
      if (make_dummies) {
        recipe <- recipe %>%
          recipes::step_dummy(all_nominal(), - all_outcomes())
      }
    }

    # Prep the newly built recipe ---------------------------------------------
    recipe <- recipes::prep(recipe, training = d)
  }

  # Bake either the newly built or passed-in recipe
  d <- recipes::bake(recipe, d)

  # Find and issue warnings. Perhaps this should be wrapped in if (verbose)
  steps <- map_chr(recipe$steps, ~ attr(.x, "class")[1])
  ## near zero variance
  if ("step_nzv" %in% steps &&
      length(nzv_removed <- recipe$steps[[which(steps == "step_nzv")]]$removals))
    warning("Removing these near-zero variance columns: ",
            paste(nzv_removed, collapse = ", "))

  # Add ignore columns back in and attach as attribute to recipe
  d <- dplyr::bind_cols(d_ignore, d)
  attr(recipe, "ignored_columns") <- unname(ignored)
  attr(d, "recipe") <- recipe
  d <- tibble::as_tibble(d)
  class(d) <- c("hcai_prepped_df", class(d))

  # TODO: Remove unused factor levels with droplevels. (MAYBE)
  return(d)
}

# print method for prep_data
#' @export
print.hcai_prepped_df <- function(x, ...) {
  message("healthcareai-prepped data. Recipe used to prepare data:\n")
  print(attr(x, "recipe"))
  message("Current data:\n")
  NextMethod(x)
  return(invisible(x))
}
