# TODO - Allow for messages to be functions
  ## defer to v2
# X - Allow for null input$answer
  ## No.  If the quiz module wants a null value, it can provide a placeholder value that is not NULL

#' Tutorial quiz questions
#'
#' @description
#' Add interactive quiz questions to a tutorial. Each quiz question is executed
#' within a shiny runtime to provide more flexibility in the types of questions
#' offered. There are four default types of quiz questions:
#'
#' \describe{
#' \item{\code{learnr_radio}}{Radio button question.  This question type will
#' only allow for a single answer submission by the user.  An answer must be
#' marked for the user to submit their answer.}
#' \item{\code{learnr_checkbox}}{Check box question.  This question type will
#' allow for one or more answers to be submitted by the user.  At least one
#' answer must be marked for the user to submit their answer.}
#' \item{\code{learnr_text}}{Text box question.  This question type will allow
#' for free form text to be submitted by the user.  At least one non-whitespace
#' character must be added for the user to submit their answer.}
#' \item{\code{learnr_numeric}}{Numeric question.  This question type will allow
#' for a number to be submitted by the user.  At least one number must be added
#' for the user to submit their answer.}
#' }
#'
#' Note, the print behavior has changed as the runtime is now Shiny based.  If
#' \code{question}s and \code{quiz}es are printed in the console, the S3
#' structure and information will be displayed.
#'
#'
#' @examples
#' quiz(
#'   question("What number is the letter A in the alphabet?",
#'     answer("8"),
#'     answer("14"),
#'     answer("1", correct = TRUE),
#'     answer("23"),
#'     incorrect = "See [here](https://en.wikipedia.org/wiki/English_alphabet) and try again.",
#'     allow_retry = TRUE
#'   ),
#'
#'   question("Where are you right now? (select ALL that apply)",
#'     answer("Planet Earth", correct = TRUE),
#'     answer("Pluto"),
#'     answer("At a computing device", correct = TRUE),
#'     answer("In the Milky Way", correct = TRUE),
#'     incorrect = paste0("Incorrect. You're on Earth, ",
#'                        "in the Milky Way, at a computer.")
#'   )
#' )
#'
#' @param text Question or option text
#' @param ... One or more questions or answers
#' @param caption Optional quiz caption (defaults to "Quiz")
#' @param type Type of quiz question. Typically this can be automatically
#'   determined based on the provided answers. Pass `"radio"` to indicate that
#'   even though multiple correct answers are specified that inputs which
#'   include only one correct answer are still correct. Pass `"checkbox"` to
#'   force the use of checkboxes (as opposed to radio buttons) even though only
#'   one correct answer was provided.
#' @param correct For `question`, text to print for a correct answer (defaults
#'   to "Correct!"). For `answer`, a boolean indicating whether this answer is
#'   correct.
#' @param incorrect Text to print for an incorrect answer (defaults to
#'   "Incorrect") when `allow_retry` is `FALSE`.
#' @param try_again Text to print for an incorrect answer when `allow_retry`
#'   is `TRUE`.
#'   Defaults to "Incorrect. Be sure to select every correct answer." for
#'   checkbox questions and "Incorrect" for non-checkbox questions.
#' @param message Additional message to display along with correct/incorrect
#'   feedback. This message is always displayed after a question submission.
#' @param post_message Additional message to display along with
#'   correct/incorrect feedback. If `allow_retry` is `TRUE`, this
#'   message will only be displayed after the correct submission.  If
#'   `allow_retry` is `FALSE`, it will produce a second message
#'   alongside the `message` message value.
#' @param loading Loading text to display as a placeholder while the question is
#'   loaded. If not provided, generic "Loading..." or placeholder elements will
#'   be displayed.
#' @param submit_button Label for the submit button. Defaults to `"Submit
#'   Answer"`
#' @param try_again_button Label for the try again button. Defaults to `"Submit
#'   Answer"`
#' @param allow_retry Allow retry for incorrect answers. Defaults to `FALSE`.
#' @param random_answer_order Display answers in a random order.
#' @param options Extra options to be stored in the question object. This is
#'   useful when using custom question types. See [sortable::question_rank()]
#'   for an example question implementation that uses the `options` parameter.
#'
#' @return A learnr quiz, or collection of questions.
#'
#' @family Interactive Questions
#' @seealso [random_praise()], [random_encouragement()]
#' @seealso For more information and question type extension examples, please
#'   see the help documentation for [question_methods][question_ui_initialize()]
#'   and view the \code{question_type} tutorial:
#'   `learnr::run_tutorial("question_type", "learnr")`.
#' @name quiz
#' @rdname quiz
#' @export
quiz <- function(..., caption = rlang::missing_arg()) {

  # create table rows from questions
  index <- 1
  questions <- lapply(list(...), function(question) {
    if (!is.null(question$label)) {
      label <- paste(question$label, index, sep="-")
      question$label <- label
      question$ids$answer <- NS(label)("answer")
      question$ids$question <- label
      index <<- index + 1
    }
    question
  })

  caption <-
    if (rlang::is_missing(caption)) {
      i18n_span("text.quiz", "Quiz")
    } else if (!is.null(caption)) {
      quiz_text(caption)
    }

  ret <- list(caption = caption, questions = questions)
  class(ret) <- "tutorial_quiz"
  ret
}


#' @rdname quiz
#' @import shiny
#' @export
question <- function(
    text,
    ...,
    type = c("auto", "single", "multiple", "learnr_radio", "learnr_checkbox", "learnr_text", "learnr_numeric"),
    correct = "Correct!",
    incorrect = "Incorrect",
    try_again = NULL,
    message = NULL,
    post_message = NULL,
    loading = NULL,
    submit_button = rlang::missing_arg(),
    try_again_button = rlang::missing_arg(),
    allow_retry = FALSE,
    random_answer_order = FALSE,
    options = list()
) {

  # one time tutor initialization
  initialize_tutorial()

  # capture/validate answers
  rlang::check_dots_unnamed() # validate all answers are not named and not a misspelling
  answers <- list(...)
  lapply(answers, function(answer) {
    checkmate::assert_class(answer, "tutorial_question_answer")
  })

  # verify chunk label if necessary
  verify_tutorial_chunk_label()

  # count total correct answers to decide between radio/checkbox
  answers_split <- answers_split_type(answers)
  total_correct <- sum(vapply(answers_split[["literal"]], `[[`, logical(1), "correct"))

  # determine or resolve question type
  if (missing(type)) {
    # no partial matching for s3 methods means we can't use match.arg()
    type <- "auto"
  }
  if (identical(type, "auto")) {
    if (total_correct > 1) {
      type <- "learnr_checkbox"
    } else {
      type <- "learnr_radio"
    }
  }
  if (length(type) == 1) {
    type <- switch(type,
      "radio" = ,
      "single" = "learnr_radio",
      "checkbox" = ,
      "multiple" = "learnr_checkbox",
      # allows for s3 methods
      type
    )
  }
  if (is.null(try_again)) {
    try_again <- if (identical(type, "learnr_checkbox")) {
      "Incorrect. Be sure to select every correct answer."
    } else {
      incorrect
    }
  }

  # ensure we have at least one correct answer, if required
  must_have_correct <- identical(type, "learnr_radio") || is.null(answers_split[["function"]])
  if (must_have_correct && total_correct == 0) {
    stop("At least one correct answer must be supplied")
  }

  # can not guarantee that `label` exists
  label <- knitr::opts_current$get('label')
  q_id <- label %||% random_question_id()

  # i18nize button labels if default values are used
  submit_button <-
    if (rlang::is_missing(submit_button)) {
      i18n_span("button.questionsubmit", "Submit Answer")
    } else {
      quiz_text(submit_button)
    }

  try_again_button <-
    if (rlang::is_missing(try_again_button)) {
      i18n_span("button.questiontryagain", "Try Again")
    } else {
      quiz_text(try_again_button)
    }

  ret <- list(
    type = type,
    label = label,
    question = quiz_text(text),
    answers = answers,
    button_labels = list(
      submit = submit_button,
      try_again = try_again_button
    ),
    messages = list(
      correct = quiz_text(correct),
      try_again = quiz_text(try_again),
      incorrect = quiz_text(incorrect),
      message = quiz_text(message),
      post_message = quiz_text(post_message)
    ),
    ids = list(
      answer = NS(q_id)("answer"),
      question = q_id
    ),
    loading = if (!is.null(loading)) quiz_text(loading),
    random_answer_order = random_answer_order,
    allow_retry = allow_retry,
    # Set a seed for local testing, even though it is overwritten for each shiny session
    seed = random_seed(),
    options = options
  )
  class(ret) <- c(type, "tutorial_question")
  ret
}

# render markdown (including equations) for quiz_text
quiz_text <- function(text) {
  if (is_html_chr(text) || is_html_tag(text)) {
    return(text)
  }
  if (!is.null(text)) {
    if (!is.character(text)) {
      text <- format(text)
    }
    # convert markdown
    md <- markdown::mark(text = text)
    if (length(str_match_all(md, "</p>", fixed = TRUE)) == 1) {
      # remove leading and trailing paragraph
      md <- sub("^<p>", "", md)
      md <- sub("</p>\n?$", "", md)
    }
    HTML(md)
  }
  else {
    NULL
  }
}

random_id <- function(txt) {
  paste0(txt, "_", as.hexmode(floor(runif(1, 1, 16^7))))
}

random_question_id <- function() {
  random_id("lnr_ques")
}

random_seed <- function() {
  stats::runif(1, 0, .Machine$integer.max)
}

shuffle <- function(x) {
  sample(x, length(x))
}

#' Knitr quiz print methods
#'
#' \code{knitr::\link[knitr]{knit_print}} methods for \code{\link{question}} and
#' \code{\link{quiz}}
#'
#' @inheritParams knitr::knit_print
#'
#' @importFrom knitr knit_print
#' @method knit_print tutorial_question
#' @export
#' @rdname knit_print
knit_print.tutorial_question <- function(x, ...) {
  question <- x
  ui <- question_module_ui(question$ids$question)

  # too late to try to set a chunk attribute
  # knitr::set_chunkattr(echo = FALSE)
  rmarkdown::shiny_prerendered_chunk(
    'server',
    sprintf(
      'learnr:::question_prerendered_chunk(%s, session = session)',
      dput_to_string(question)
    )
  )

  # regular knit print the UI
  knitr::knit_print(ui)
}

#' @method knit_print tutorial_quiz
#' @export
#' @rdname knit_print
knit_print.tutorial_quiz <- function(x, ...) {
  quiz <- x
  caption_tag <- if (!is.null(quiz$caption)) {
    list(knitr::knit_print(
      tags$div(class = "panel-heading tutorial-quiz-title", quiz$caption)
    ))
  }

  append(
    caption_tag,
    lapply(quiz$questions, knitr::knit_print)
  )
}


retrieve_all_question_submissions <- function(session) {
  state_objects <- get_all_state_objects(session, exercise_output = FALSE)

  # create submissions from state objects
  submissions <- submissions_from_state_objects(state_objects)

  submissions
}

retrieve_question_submission_answer <- function(session, question_label) {
  question_label <- as.character(question_label)

  for (submission in retrieve_all_question_submissions(session)) {
    if (identical(as.character(submission$id), question_label)) {
      return(submission$data$answer)
    }
  }
  return(NULL)
}




question_prerendered_chunk <- function(question, ..., session = getDefaultReactiveDomain()) {
  store_question_cache(question)

  question_state <-
    callModule(
      question_module_server,
      question$ids$question,
      question = question,
      session = session
    )

  observe({
    req(question_state())
    set_tutorial_state(question$label, question_state(), session = session)
  })

  question_state
}

question_module_ui <- function(id) {
  ns <- NS(id)
  div(
    class = "panel panel-default tutorial-question-container",
    div(
      "data-label" = as.character(id),
      class = "tutorial-question panel-body",
      uiOutput(ns("answer_container")),
      uiOutput(ns("message_container")),
      uiOutput(ns("action_button_container")),
      withLearnrMathJax()
    )
  )
}

question_module_server <- function(
  input, output, session,
  question
) {

  output$answer_container <- renderUI({
    if (is.null(question$loading)) {
      question_ui_loading(question)
    } else {
      div(
        class="loading",
        question$loading
      )
    }
  })

  # Setup reactive here that will be updated by the question modules
  question_state <- reactiveVal()

  observeEvent(
    req(session$userData$learnr_state() == "restored"),
    once = TRUE,
    question_module_server_impl(input, output, session, question, question_state)
  )

  question_state
}

question_module_server_impl <- function(
  input, output, session,
  question,
  question_state = NULL
) {

  ns <- getDefaultReactiveDomain()$ns
  # set a seed for each user session for question methods to use
  question$seed <- random_seed()

  # only set when a submit button has been pressed
  # (or reset when try again is hit)
  # (or set when restoring)
  submitted_answer <- reactiveVal(NULL, label = "submitted_answer")

  is_correct_info <- reactive(label = "is_correct_info", {
    # question has not been submitted
    if (is.null(submitted_answer())) return(NULL)
    # find out if answer is right
    ret <- question_is_correct(question, submitted_answer())
    if (!inherits(ret, "learnr_mark_as")) {
      stop("`question_is_correct(question, input$answer)` must return a result from `correct`, `incorrect`, or `mark_as`")
    }
    ret
  })

  # should present all messages?
  is_done <- reactive(label = "is_done", {
    if (is.null(is_correct_info())) return(NULL)
    (!isTRUE(question$allow_retry)) || is_correct_info()$correct
  })


  button_type <- reactive(label = "button type", {
    if (is.null(submitted_answer())) {
      "submit"
    } else {
      # is_correct_info() should be valid
      if (is.null(is_correct_info())) {
        stop("`is_correct_info()` is `NULL` in a place it shouldn't be")
      }

      # update the submit button label
      if (is_correct_info()$correct) {
        "correct"
      } else {
        # not correct
        if (isTRUE(question$allow_retry)) {
          # not correct, but may try again
          "try_again"
        } else {
          # not correct and can not try again
          "incorrect"
        }
      }
    }
  })

  # disable / enable for every input$answer change
  answer_is_valid <- reactive(label = "answer_is_valid", {
    if (is.null(submitted_answer())) {
      question_is_valid(question, input$answer)
    } else {
      question_is_valid(question, submitted_answer())
    }
  })

  init_question <- function(restoreValue = NULL) {
    if (question$random_answer_order) {
      # Shuffle visible answer options (i.e. static, non-function answers)
      is_visible_option <- !answer_type_is_function(question$answers)
      question$answers[is_visible_option] <<- shuffle(question$answers[is_visible_option])
    }
    submitted_answer(restoreValue)
  }

  # restore past submission
  #  If no prior submission, it returns NULL
  past_submission_answer <- retrieve_question_submission_answer(session, question$label)
  # initialize like normal... nothing has been submitted
  #   or
  # initialize with the past answer
  #  this should cascade throughout the app to display correct answers and final outputs
  init_question(past_submission_answer)


  output$action_button_container <- renderUI({
    question_button_label(
      question,
      button_type(),
      answer_is_valid()
    )
  })

  output$message_container <- renderUI({
    req(!is.null(is_correct_info()), !is.null(is_done()))

    withLearnrMathJax(
      question_messages(
        question,
        messages = is_correct_info()$messages,
        is_correct = is_correct_info()$correct,
        is_done = is_done()
      )
    )
  })

  output$answer_container <- renderUI({
    if (is.null(submitted_answer())) {
      # has not submitted, show regular answers
      return(
        # if there is an existing input$answer, display it.
        # if there is no answer... init with NULL
        # Do not re-render the UI for every input$answer change
        withLearnrMathJax(
          question_ui_initialize(question, isolate(input$answer))
        )
      )
    }

    # has submitted

    if (is.null(is_done())) {
      # has not initialized
      return(NULL)
    }

    if (is_done()) {
      # if the question is 'done', display the final input ui and disable everything

      return(
        withLearnrMathJax(
          question_ui_completed(question, submitted_answer())
        )
      )
    }

    # if the question is NOT 'done', disable the current UI
    #   until it is reset with the try again button

    return(
      withLearnrMathJax(
        question_ui_try_again(question, submitted_answer())
      )
    )
  })


  observeEvent(input$action_button, {

    if (button_type() == "try_again") {
      # maintain current submission / do not randomize answer order
      # only reset the submitted answers
      # does NOT reset input$answer
      submitted_answer(NULL)

      # submit "reset" to server
      event_trigger(
        session,
        "reset_question_submission",
        data = list(
          label    = as.character(question$label),
          question = as.character(question$question)
        )
      )
      return()
    }

    submitted_answer(input$answer)

    # submit question to server
    event_trigger(
      session = session,
      event   = "question_submission",
      data    = list(
        label    = as.character(question$label),
        question = as.character(question$question),
        answer   = as.character(input$answer),
        correct  = is_correct_info()$correct
      )
    )

  })

  observe({
    # Update the `question_state()` reactive to report state back to the Shiny session
    req(submitted_answer(), is.reactive(question_state))
    current_answer_state <- list(
      type = "question",
      answer = submitted_answer(),
      correct = is_correct_info()$correct
    )
    question_state(current_answer_state)
  })
}



question_button_label <- function(question, label_type = "submit", is_valid = TRUE) {
  label_type <- match.arg(label_type, c("submit", "try_again", "correct", "incorrect"))

  if (label_type %in% c("correct", "incorrect")) {
    # No button when answer is correct or incorrect (wrong without try again)
    return(NULL)
  }

  button_label <- question$button_labels[[label_type]]
  is_valid <- isTRUE(is_valid)

  default_class <- "btn-primary"
  warning_class <- "btn-warning"

  action_button_id <- NS(question$ids$question)("action_button")

  if (label_type == "submit") {
    button <- actionButton(
      action_button_id, button_label,
      class = default_class
    )
    if (!is_valid) {
      button <- disable_all_tags(button)
    }
    button
  } else if (label_type == "try_again") {
    mutate_tags(
      actionButton(
        action_button_id, button_label,
        class = warning_class
      ),
      paste0("#", action_button_id),
      function(ele) {
        ele$attribs$class <- str_remove(ele$attribs$class, "\\s+btn-default")
        ele
      }
    )
  }
}

question_messages <- function(question, messages, is_correct, is_done) {

  # Always display the incorrect, correct, or try again messages
  default_message <-
    if (is_correct) {
      question$messages$correct
    } else {
      # not correct
      if (is_done) {
        question$messages$incorrect
      } else {
        question$messages$try_again
      }
    }

  if (!is.null(messages)) {
    if (!is.list(messages)) {
      # turn vectors into lists
      messages <- tagList(messages)
    }
  }

  # display the default messages first
  if (!is.null(default_message)) {
    if (!is.null(messages)) {
      messages <- tagList(default_message, messages)
    } else {
      messages <- default_message
    }
  }

  # get regular message
  if (is.null(messages)) {
    message_alert <- NULL
  } else {
    alert_class <- if (is_correct) "alert-success" else "alert-danger"
    if (length(messages) > 1) {
      # add breaks inbetween similar messages
      break_tag <- list(tags$br(), tags$br())
      all_messages <- replicate(length(messages) * 2 - 1, {break_tag}, simplify = FALSE)
      # store in all _odd_ positions
      all_messages[(seq_along(messages) * 2) - 1] <- messages
      messages <- tagList(all_messages)
    }
    message_alert <- tags$div(
      class = paste0("alert ", alert_class),
      messages
    )
  }


  if (is.null(question$messages$message)) {
    always_message_alert <- NULL
  } else {
    always_message_alert <- tags$div(
      class = "alert alert-info",
      question$messages$message
    )
  }

  # get post question message only if the question is done
  if (isTRUE(is_done) && !is.null(question$messages$post_message)) {
    post_alert <- tags$div(
      class = "alert alert-info",
      question$messages$post_message
    )
  } else {
    post_alert <- NULL
  }

  # set UI message
  if (all(
    is.null(message_alert),
    is.null(always_message_alert),
    is.null(post_alert)
  )) {
    NULL
  } else {
    htmltools::tagList(message_alert, always_message_alert, post_alert)
  }
}

question_ui_loading <- function(question) {
  prompt <- format(question$question)
  n_paragraphs <- max(length(str_match_all(prompt, "</p>")), 1)
  paras <- lapply(seq_len(n_paragraphs), function(...) {
    spans <- lapply(seq_len(sample(2:4, 1)), function(...) {
      htmltools::span(class = sprintf("placeholder col-%s", sample(2:7, 1)))
    })
    htmltools::p(spans)
  })

  q_opts <- NULL
  if (length(intersect(question$type, c("learnr_radio", "learnr_checkbox"))) > 0) {
    q_opts <- htmltools::tags$ul(
      lapply(seq_along(question$answers), function(...) {
        htmltools::tags$li(
          htmltools::span(class = "placeholder col-3")
        )
      })
    )
  }

  button <- htmltools::tags$a(
    href = "#",
    tabindex = "-1",
    class = "btn btn-primary disabled placeholder col-3",
    `aria-hidden` = "true"
  )

  htmltools::div(
    class = "loading placeholder-glow",
    paras,
    q_opts,
    button
  )
}



withLearnrMathJax <- function(...) {
  htmltools::tagList(
    ...,
    htmltools::tags$script(
      # only attempt function if it exists
      htmltools::HTML("if (Tutorial.triggerMathJax) Tutorial.triggerMathJax()")
    )
  )
}
