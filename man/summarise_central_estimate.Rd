% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/summarise_seromodel.R
\name{summarise_central_estimate}
\alias{summarise_central_estimate}
\title{Summarise central estimate}
\usage{
summarise_central_estimate(
  seromodel,
  serosurvey,
  alpha,
  par_name = "seroreversion_rate",
  central_estimate_digits = 2
)
}
\arguments{
\item{seromodel}{stan_fit object obtained from sampling a model
with \link{fit_seromodel}}

\item{serosurvey}{\describe{
\item{\code{survey_year}}{Year in which the survey took place
(only needed to plot time models)}
\item{\code{age_min}}{Floor value of the average between age_min and age_max}
\item{\code{age_max}}{The size of the sample}
\item{\code{n_sample}}{Number of samples for each age group}
\item{\code{n_seropositive}}{Number of positive samples for each age group}
}}

\item{alpha}{1 - alpha indicates the credibility level to be used}

\item{par_name}{String specifying the parameter to be extracted
from \code{seromodel}}

\item{central_estimate_digits}{Number of central estimate digits}
}
\value{
Text summarising specified central estimate
}
\description{
Summarise central estimate
}
\examples{
data(veev2012)
seromodel <- fit_seromodel(veev2012, iter = 100)
summarise_central_estimate(
  seromodel,
  veev2012,
  alpha = 0.05,
  par_name = "foi"
  )
}
