#' Create caterpillar plots from rstan's stanfit objects
#'
#' @param obj a \code{stanfit} object
#' @param pars scalar or vector regular expressions for parameter
#' labels that you would like to plot as declared in \code{model_code} from the
#' \code{\link{stan}} call.
#' @param pars_labels vector of parameter labels for the output plot. Important:
#' they must be in the same order as in the \code{stanfit} object when
#' \code{as.data.frame(obj)} is called.
#' @param hpd logical. If \code{TRUE} then the 90\% and 95\% highest probability
#' density intervals (HDI) are found. If \code{FALSE} then the corresponding
#' central intervals are found.
#' @param order_medians logical. Whether or not to order the points by their
#' medians.
#' @param horizontal logical. Whether or not you would like the lines to be
#' horizontal
#' @param alpha_bounds numeric. Alpha transparency value for the uncertainty
#' bounds.
#'
#' @details Points plot the simulations' medians, thin lines represent the 95%
#' HPD/central intervals, and thick lines represent the 90% HPD/central
#' intervals.
#'
#' @examples
#' \dontrun{
#' # Create Stan model
#' library(rstan)
#' scode <- "
#'    parameters {
#'        real y[2];
#'    }
#'    model {
#'        y[1] ~ normal(0, 1);
#'        y[2] ~ double_exponential(0, 2);
#'    }
#' "
#'
#' # Run
#' fit <- stan(model_code = scode, iter = 10000, verbose = FALSE)
#'
#' # Plot y[1] and y[2] parameters
#' stan_caterpillar(fit, pars = 'y\\[.*\\]')
#' }
#'
#' @seealso \link{rstan}, \code{\link{stan}}, \code{ggmcmc}
#'
#' @import rstan
#' @importFrom tidyr gather
#' @importFrom dplyr group_by summarise inner_join %>%
#' @import ggplot2
#' @importFrom stats median quantile reorder
#'
#' @export

stan_caterpillar <- function(obj,
                            pars,
                            pars_labels = NULL,
                            hpd = TRUE,
                            order_medians = TRUE,
                            horizontal = TRUE,
                            alpha_bounds = 0.3)
{
    variable <- value <- NULL

    # Extract all simulations
    sims <- as.data.frame(obj)

    # Extract only desired parameters
    names <- names(sims)
    sims_subset <- sims[, names %in% grep(pattern = pars, x = names,
                                          value = TRUE)] %>% data.frame()

    if (ncol(sims_subset) == 0) {
        stop("No parameters selected. \n", call. = FALSE)
    }
    # Gather for plotting
    gathered <- gather(sims_subset, variable, value)

    # Add labels
    if (!is.null(pars_labels)) {
        message("\nEnsure that your parameter labels are in the same order as the parameters.\n")
        if (length(pars_labels) !=
                length(unique(gathered$variable))) {
            stop("pars_labels must equal the number of plotted parameters.",
                 call. = FALSE)
        }
        gathered$variable <- factor(gathered$variable,
                                    labels = pars_labels)
    }

    if (isTRUE(hpd)) {
        gathered <- group_by(gathered, variable)
        lower95 <- summarise(gathered, HPD(value, prob = 0.95, side = 'lower'))
        lower90 <- summarise(gathered, HPD(value, prob = 0.9, side = 'lower'))
        upper90 <- summarise(gathered, HPD(value, prob = 0.9, side = 'upper'))
        upper95 <- summarise(gathered, HPD(value, prob = 0.95, side = 'upper'))

    }

    else if (!isTRUE(hpd)){
        # Find central interval
        gathered <- group_by(gathered, variable)
        lower95 <- summarise(gathered, quantile(value, 0.025))
        lower90 <- summarise(gathered, quantile(value, 0.05))
        upper90 <- summarise(gathered, quantile(value, 0.95))
        upper95 <- summarise(gathered, quantile(value, 0.975))
    }

    # Find medians
    medians <- summarise(gathered, median(value))

    # Merge
    comb <- suppressMessages(inner_join(lower95, lower90))
    comb <- suppressMessages(inner_join(comb, medians))
    comb <- suppressMessages(inner_join(comb, upper90))
    comb <- suppressMessages(inner_join(comb, upper95))
    names(comb) <- c('pars', 'lower95', 'lower90', 'medians', 'upper90',
                     'upper95')

    # Plot
    if (isTRUE(order_medians)){
        pp <- ggplot(comb, aes(x = medians, y = reorder(pars, medians),
                               xmin = lower95,
                               xmax = upper95)) +
            geom_point(size = 3) +
            geom_segment(aes(x = lower95, xend = upper95,
                             yend = reorder(pars, medians)), size = 0.5,
                             alpha = alpha_bounds) +
            geom_segment(aes(x = lower90, xend = upper90,
                             yend = reorder(pars, medians)), size = 1.5,
                             alpha = alpha_bounds) +
            xlab('') + ylab('') +
            theme_bw()
    }
    else {
        pp <- ggplot(comb, aes(x = medians, y = pars,
                               xmin = lower95,
                               xmax = upper95)) +
            geom_point(size = 3) +
            geom_segment(aes(x = lower95, xend = upper95, yend = pars),
                         size = 0.5, alpha = alpha_bounds) +
            geom_segment(aes(x = lower90, xend = upper90,
                             yend = pars), size = 1.5, alpha = alpha_bounds) +
            xlab('') + ylab('') +
            theme_bw()
    }

    if (!isTRUE(horizontal)) pp <- pp + coord_flip()

    return(pp)
}
