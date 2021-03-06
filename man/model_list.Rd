% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/model_list_constructors.R
\name{model_list}
\alias{model_list}
\title{Constructor function for class model_list}
\usage{
model_list(model_class, ...)
}
\arguments{
\item{model_class}{Every model_list object has a child class that specifies
the model_class. Currently classification and regression are supported.}

\item{...}{Models to become a model_list, but you should use as.model_list}
}
\value{
An empty list with classes list, model_list, and type_list
}
\description{
Constructor function for class model_list
}
\examples{
model_list("regression")
}
