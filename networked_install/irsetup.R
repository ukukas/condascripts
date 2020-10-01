install.packages('IRkernel', normalizePath(.Library), quiet = TRUE,
                 repos = 'https://cloud.r-project.org/')
IRkernel::installspec(user = FALSE)
