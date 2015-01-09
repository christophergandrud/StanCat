#' Find one bound of the highest probability density of a vector of simulations
#'
#' @param x numeric vector of simulations to find the HPD of.
#' @param prob numeric scalar in the interval (0,1) giving the target
#' probability content of the intervals.
#' @param side character either \code{'lower'} or \code{'upper'} specifying
#' whether to return the lower or upper bound of the interval.
#'
#' @importFrom coda as.mcmc HPDinterval
#' @keywords internals
#' @noRd

HPD <- function(x, prob, side){
    both <- as.mcmc(x) %>% HPDinterval(prob = prob)
    if (side == 'lower') {
        out <- both[1]
    }
    else if (side == 'upper'){
        out <- both[2]
    }
}
