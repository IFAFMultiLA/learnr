

# ' S3 method to recursively look for elements according to a basic css string.
# ' This method should not be used publically until adopted by \code{htmltools}.
# ' @param selector css selector string
# ' @param fn function to execute when a match is found
# ' @param ... possible future parameter extension
# Export only due to knitr execution not finding mutate_tags
mutate_tags <- function(ele, selector, fn, ...) {
  UseMethod("mutate_tags", ele)
}

#' @export
mutate_tags.default <- function(ele, selector, fn, ...) {
  if (any(
    c(
      "NULL",
      "numeric", "integer", "complex",
      "logical",
      "character", "factor"
    ) %in% class(ele)
  )) {
    return(ele)
  }

  # if not a basic type, recurse on the tags
  mutate_tags(
    htmltools::as.tags(ele),
    selector,
    fn,
    ...
  )
}

#' @export
mutate_tags.list <- function(ele, selector, fn, ...) {
  # set values to maintain attrs and class values
  ele[] <- lapply(
    ele,
    function(item) {
      mutate_tags(item, selector, fn, ...)
    }
  )
  ele
}

#' @export
mutate_tags.shiny.tag <- function(ele, selector, fn, ...) {
  # # vectorize selector.  (Currently not used, so removed)
  # if (inherits(selector, "character")) {
  #   # if there is a set of selectors
  #   if (grepl(",", selector)) {
  #     selectors <- strsplit(selector, ",")[[1]]
  #     # serially mutate the tags for each indep selector
  #     for (selector_i in selectors) {
  #       ele <- mutate_tags(ele, selector_i, fn, ...)
  #     }
  #     return(ele)
  #   }
  # }

  # make sure it's a selector
  selector <- as_selector_list(selector)
  # grab the first element
  cur_selector <- selector[[1]]

  is_match <- TRUE
  if (!cur_selector$match_everything) {
    # match on element
    if (is_match && !is.null(cur_selector$element)) {
      is_match <- ele$name == cur_selector$element
    }
    # match on id
    if (is_match && !is.null(cur_selector$id)) {
      is_match <- (ele$attribs$id %||% "") == cur_selector$id
    }
    # match on class values
    if (is_match && !is.null(cur_selector$classes)) {
      is_match <- all(strsplit(ele$attribs$class %||% "", " ")[[1]] %in% cur_selector$classes)
    }

    # if it is a match, drop a selector
    if (is_match) {
      selector <- selector[-1]
    }
  }

  # if there are children and remaining selectors, recurse through
  if (length(selector) > 0 && length(ele$children) > 0) {
    ele$children <- lapply(ele$children, function(x) {
      mutate_tags(x, selector, fn, ...)
    })
  }

  # if it was a match
  if (is_match) {
    if (
      # it is a "leaf" match
      length(selector) == 0 ||
      # or should match everything
      cur_selector$match_everything
    ) {
      # update it
      ele <- fn(ele, ...)
    }
  }

  # return the updated element
  ele
}


disable_element_fn <- function(ele) {
  tagAppendAttributes(
    ele,
    class = "disabled",
    disabled = NA
  )
}

disable_tags <- function(ele, selector) {
  mutate_tags(ele, selector, disable_element_fn)
}

#' Disable all html tags
#'
#' Method to disable all html tags to not allow users to interact with the html.
#'
#' @examples
#' # add an href to all a tags
#' disable_all_tags(
#'   htmltools::tagList(
#'     htmltools::a(),
#'     htmltools::a()
#'   )
#' )
#'
#' @param ele html tag element
#'
#' @return An \pkg{htmltools} HTML object with appended `class = "disabled"` and
#'   `disabled` attributes on all tags.
#'
#' @export
disable_all_tags <- function(ele) {
  mutate_tags(ele, "*", disable_element_fn)
}

#' Finalize a question
#'
#' Mark a question as finalized by adding a `question-final` class to the HTML
#' output at the top level, in addition to disabling all tags with
#' [disable_all_tags()].
#'
#' @examples
#' # finalize the question UI
#' finalize_question(
#'   htmltools::div(
#'     class = "custom-question",
#'     htmltools::div("answer 1"),
#'     htmltools::div("answer 2")
#'   )
#' )
#'
#' @inheritParams disable_all_tags
#'
#' @return An \pkg{htmltools} HTML object with appropriately appended classes
#'   such that a tutorial question is marked as the final answer.
#'
#' @export
finalize_question <- function(ele) {
  ele <- disable_all_tags(ele)
  if (inherits(ele, "shiny.tag.list")) {
    ele_class <- class(ele)
    ele <- lapply(ele, function(el) tagAppendAttributes(el, class = "question-final"))
    class(ele) <- ele_class
  } else {
    ele <- tagAppendAttributes(ele, class = "question-final")
  }
  ele
}
