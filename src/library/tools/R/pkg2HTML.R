#  File src/library/tools/R/pkg2HTML.R
#
#  Copyright (C) 2023 The R Core Team
#  Part of the R package, https://www.R-project.org
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  A copy of the GNU General Public License is available at
#  https://www.R-project.org/Licenses/


## Experimental interface to convert package source directory into
## single-page manual

## FIXME: Rd2HTML(standalone=FALSE) needs to include mathjaxr
## detection results in the info attribute.

## This cannot be done per Rd file, but we can switch to mathjaxr if
## any Rd file in a package uses mathjaxr

.convert_package_rdfiles <- function(package, dir = NULL, lib.loc = NULL, ...,
                                     stages = "build")
{
    ## if 'package' is an installed package (simplest) just use
    ## Rd_db(package) to get parsed Rd files. Otherwise, if 'package'
    ## is a .tar.gz file, assume that it's a source package (so unpack
    ## and call Rd_db on those). If 'package' is missing but 'dir' is
    ## not, interpret as source package (no need to unpack)

    isPkgTarball <- function(x) {
        length(x) == 1L && 
            endsWith(x, "tar.gz") &&
            length(strsplit(basename(x), "_", fixed = TRUE)[[1]]) == 2L
    }
    isURL <- function(x) {
        length(x) == 1L && 
            (startsWith(x, "http://") || startsWith(x, "https://"))
    }
    db <- 
        if (!missing(package) && isTRUE(isPkgTarball(package)))
        {
            ## If URL, download first
            if (isURL(package)) {
                destdir <- tempfile("dir")
                if (!dir.create(destdir))
                    stop(gettextf("unable to create temporary directory %s",
                                  sQuote(destdir)))
                utils::download.file(package, destfile = file.path(destdir, basename(package)))
                package <- file.path(destdir, basename(package))
            }
            ## TODO: need to unpack first.
            ## Copied from src/library/utils/R/unix/mac.install.R::unpackPkg
            tmpDir <- tempfile("pkg")
            if (!dir.create(tmpDir))
                stop(gettextf("unable to create temporary directory %s",
                              sQuote(tmpDir)))
            utils::untar(package, exdir = tmpDir)
            pkgdir <- list.dirs(tmpDir, recursive = FALSE)
            if (length(pkgdir) != 1)
                stop(gettextf("expected one package directory, found %d.",
                              length(pkgdir)))
            Rd_db(dir = pkgdir, stages = stages)
        }
        else {
            pkgdir <- if (is.null(dir)) find.package(package, lib.loc) else dir
            Rd_db(package, dir, lib.loc, stages = stages)
        }

    ## create links database for help links. Level 0 links are
    ## obtained directly from the db, which is useful for non-installed packages.
    Links0 <- .build_links_index(db, pkgdir)
    Links <- c(Links0, findHTMLlinks(pkgdir, level = 1))
    Links2 <- findHTMLlinks(level = 2)
    
    rd2lines <- function(Rd, ...) {
        ## Rd2HTML() returns output location, which is not useful
        ## here, but also attributes that are.
        outlines <-
            utils::capture.output(
                       h <- Rd2HTML(Rd, out = "",
                                    package = pkgdir, # to extract pkgname/version info
                                    Links = Links, Links2 = Links2,
                                    ...)
                   )
        list(outlines = outlines, info = attr(h, "info"))
    }
    structure(lapply(db, rd2lines, standalone = FALSE, ...),
              descfile = file.path(pkgdir, "DESCRIPTION"))

}



pkg2HTML <- function(package, dir = NULL, lib.loc = NULL,
                     outputEncoding = "UTF-8",
                     stylesheet = R.home("doc/html/R-nav.css"),
                     hooks = list(pkg_href = function(pkg) sprintf("%s.html", pkg)),
                     texmath = getOption("help.htmlmath"),
                     prism = TRUE,
                     out = NULL,
                     ...,
                     Rhtml = FALSE,
                     include_description = TRUE)
{
    if (is.null(texmath)) texmath <- "katex"
    hcontent <- .convert_package_rdfiles(package, dir, lib.loc,
                                         Rhtml = Rhtml, hooks = hooks, ...)
    descfile <- attr(hcontent, "descfile")
    pkgname <- read.dcf(descfile, fields = "Package")[1, 1]
    if (is.null(out)) {
        out <- if (is.null(hooks$pkg_href)) ""
               else hooks$pkg_href(pkgname)
    }
    
    ## Sort by name, as in PDF manual (check exact code)
    hcontent <- hcontent[order(vapply(hcontent,
                                      function(h) h$info$name,
                                      ""))]
    rdnames <- vapply(hcontent, function(h) h$info$name, "")
    rdtitles <- vapply(hcontent, function(h) h$info$title[[1L]], "")
    ## rdtitles <- vapply(hcontent, function(h) h$info$htmltitle[[1L]], "") # FIXME: has extra <p>

    ## toclines <- sprintf("<li><a href='#%s'><em>%s</em></a></li>", rdnames, rdtitles)

    toclines <- sprintf("<li><a href='#%s'>%s</a></li>", rdnames, rdtitles)

    ## Now to make a file with header + DESCRIPTION + TOC + content + footer

    hfcomps <- # should we be able to specify static URLs here?
        HTMLcomponents(title = paste0("Help for package ", pkgname), logo = FALSE,
                       up = NULL, top = NULL,
                       css = stylesheet,
                       outputEncoding = outputEncoding,
                       dynamic = FALSE, prism = prism,
                       doTexMath = TRUE, # FIXME should depend on mathjaxr use...
                       texmath = texmath)

    writeHTML <- function(..., sep = "\n", append = TRUE)
        cat(..., file = out, sep = sep, append = append)

    ## cat(hfcomps$header, fill = TRUE) # debug
    writeHTML(hfcomps$header, sep = "", append = FALSE)
    ## writeHTML(sprintf("<header class='top'><h1>Package {%s}</h1><hr></header>",
    ##                   pkgname))
    writeHTML('<nav aria-label="Topic Navigation">',
              '<div class="dropdown-menu">',
              sprintf('<h1>Package {%s}</h1>', pkgname),
              '<h2>Contents</h2>',
              '<ul class="menu">',
              toclines,
              '</ul>',
              '</div>',
              '<hr>',
              '</nav>',
              '<main>')

    if (include_description) writeHTML(.DESCRIPTION_to_HTML(descfile))
    lapply(hcontent, function(h) writeHTML("<hr>", h$outlines))
    writeHTML('</main>')
    writeHTML(hfcomps$footer, sep = "")
    invisible(out)
}


