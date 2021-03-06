#' healthcareai: Streamlined Machine Learning
#'
#' healthcare-ai provides a clean interface to create and compare multiple
#' models on your data and then deploy the model that is most accurate. healthcareai
#' also includes functions for data exploration, data cleaning, and model evaluation.
#'
#' Modeling is done in a three-step process: First, loading, understanding, and
#' preparing the data. Second, tuning and selecting a best model. Third, making
#' predictions, deploying the model, and monitoring over time.
#'
#' \enumerate{
#' \item{\strong{Load data}}{\cr
#' \item \code{\link{selectData}} to pull data directly from a SQL
#' database}
#' \item{\strong{Profile data}}{\cr
#' \item \code{\link{control_chart}} to plot data over time.
#' \item \code{\link{pivot}} if you multiple rows for each observation you want
#' a prediction on (e.g. multiple lab values for patients on separate rows), pivot
#' can help reshape the data.
#' }
#' \item{\strong{Prepare data for modeling}}{\cr
#' \item \code{\link{missingness}} to examine how much of each variable is missing.
#' \item \code{\link{impute}} to impute missing values, or...
#' \item \code{\link{prep_data}} to impute and perform additional data
#' manipulation to get data ready for machine learning.
#' \item \code{\link{split_train_test}} to split data into one data frame for
#' developing a model and another for evaluating the model.
#' }
#' \item{\strong{Tune machine learning models}}{\cr
#' \item \code{\link{machine_learn}} does all the work for you, from imputing
#' missing values to finding optimal models via cross validation. If you want to
#' keep the guts under the hood (apologies for the mixed metaphor!),
#' this is the function for you!
#' \item \code{\link{tune_models}} gives you more control over how models are trained.
#' }
#' \item{\strong{Assess models}}{\cr
#' \item \code{machine_learn} and \code{tune_models} both return
#' \code{model_list} objects. You can get high level information about your models by simply
#' printing the model_list object (i.e. type the name of the variable holding the models).
#' \item \code{summary(model_list)} provides even more information about model tuning.
#' \item \code{plot(model_list)} plots model performance over hyperparameter space.
#' }
#' \item{\strong{Make predictions and deploy the model}}{\cr
#' \item \code{\link{predict.model_list}} generates predictions
#' \item \code{\link{writeData}} to push the predicted values into a SQL environment.}
#' }
#'
#' @references \url{https://github.com/HealthCatalyst/healthcareai-r/}
#' @references \url{http://healthcare.ai}
#' @docType package
#' @name healthcareai
NULL
