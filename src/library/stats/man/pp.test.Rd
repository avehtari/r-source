% File src/library/stats/man/pp.test.Rd
% Part of the R package, https://www.R-project.org
% Copyright 1995-2018 R Core Team
% Distributed under GPL 2 or later

\newcommand{\bibcite}{#1}

\name{PP.test}
\alias{PP.test}
\title{\I{Phillips}-\I{Perron} Test for Unit Roots}
\usage{
PP.test(x, lshort = TRUE)
}
\arguments{
  \item{x}{a numeric vector or univariate time series.}
  \item{lshort}{a logical indicating whether the short or long version
    of the truncation lag parameter is used.}
}
\description{
  Computes the \I{Phillips}-\I{Perron} test for the null hypothesis that
  \code{x} has a unit root against a stationary alternative.
}
\details{
  The general regression equation which incorporates a constant and a
  linear trend is used and the corrected t-statistic for a first order
  autoregressive coefficient equals one is computed.  To estimate
  \code{sigma^2} the \I{Newey}-\I{West} estimator is used.  If \code{lshort}
  is \code{TRUE}, then the truncation lag parameter is set to
  \code{trunc(4*(n/100)^0.25)}, otherwise
  \code{trunc(12*(n/100)^0.25)} is used.  The p-values are
  interpolated from Table 4.2, page 103 of
  \bibcite{Banerjee \abbr{et al.}\sspace(1993)}.

  Missing values are not handled.
}
\value{
  A list with class \code{"htest"} containing the following components:
  \item{statistic}{the value of the test statistic.}
  \item{parameter}{the truncation lag parameter.}
  \item{p.value}{the p-value of the test.}
  \item{method}{a character string indicating what type of test was
    performed.}
  \item{data.name}{a character string giving the name of the data.}
}
\references{
  A. Banerjee, J. J. Dolado, J. W. Galbraith, and D. F. Hendry (1993).
  \emph{Cointegration, Error Correction, and the Econometric Analysis
    of Non-Stationary Data}.
  Oxford University Press, Oxford.

  P. Perron (1988).
  Trends and random walks in macroeconomic time series.
  \emph{Journal of Economic Dynamics and Control}, \bold{12}, 297--332.
  \doi{10.1016/0165-1889(88)90043-7}.
}
\author{A. Trapletti}
\examples{
x <- rnorm(1000)
PP.test(x)
y <- cumsum(x) # has unit root
PP.test(y)
}
\keyword{ts}
