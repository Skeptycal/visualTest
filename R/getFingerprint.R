
#' Get Image Fingerprint
#'
#'
#' Get a fingerprint of an image, that does not depend on the
#' fine details of the image. The fingerprint can be used to
#' compare images generated on different machines, platforms, etc.
#' It supports PNG, JPG and BMP images currently.
#'
#' It implements two algorithms. The default algorithm uses a
#' Discrete Cosine Transform (DCT). It first resizes both images
#' into 64x64 size to speed up further calculations. Then it
#' calculates the DCT of both images, takes the top-left 8x8
#' cells of the DCT, and calculate the difference to the median
#' DCT for both. The result is a 64-bit string represented as
#' a hexadecimal string. The algorithm is similar to and inspired
#' by phash (\url{http://www.phash.org/}) and imagehash
#' (\url{https://github.com/jenssegers/imagehash}).
#'
#' The \code{original} algorithm calculates the Fast Discrete
#' Fourier Transform of both images, columnwise. Then it takes
#' the imaginary parts of the results, sums them up rowwise,
#' and checks when the sums switch sign.
#'
#' @param file single character naming PNG, JPG or BMP file
#'   from which to get fingerprint. It can also be a gzip compressed
#'   file with extension \code{.gz}.
#' @param algorithm fingerprint algorithm. Possible values:
#'   \code{original}, \code{dct}. See details below.
#'
#' @export
#' @importFrom tools file_ext
#' @importFrom stats mvfft
#'
#' @examples
#' getFingerprint(
#'   system.file(package = "visualTest", "compare", "stest-00.jpg.gz")
#' )

getFingerprint <- function(file, algorithm = c("dct", "original")) {

  if (missing(file) || length(file) == 0) stop("file is missing")
  if (length(file) > 1) warning("only first value of file will be used")

  algorithm <- match.arg(algorithm)

  image <- get_reader(file)(file)

  if (algorithm == "original") {
    getFingerprintOriginal(image)

  } else if (algorithm == "dct") {
    getFingerprintDCT(image)
  }
}

getFingerprintOriginal <- function(image) {

  ## We drop the alpha channel, if present
  imageArray <- image[ , , 1:3, drop = FALSE]
  imageMat <- rgb2Value(imageArray)

  ## Alternative implementation for some images
  if (abs(min(imageMat) - max(imageMat)) < 1e-10) {
    imageMat <- rgb2Value2(imageArray)
  }

  ## To avoid numeric errors
  imageMat[] <- round(imageMat, digits = 8)

  ## perform fast fourier transform
  ftImage <- mvfft(imageMat)

  ## To avoid numeric errors
  ftImage[] <- round(ftImage, digits = 8)

  ## squash the signal into 1D
  sumImage <- apply(Im(ftImage), MARGIN = 1, sum)

  zeros <- isCross(x = sumImage, len = 3)

  diff(which(zeros))
}

#' @importFrom stats median

getFingerprintDCT <- function(image) {

  ## Resample image
  image <- bilinearInterpolation(image * 255, c(64, 64))

  ## Get luma value
  image1 <- floor(image[,,1] * 0.299 + image[,,2] * 0.587 + image[,,3] * 0.114)

  ## DCT for each row and column (apply transposes)
  image_dct <- apply(apply(image1, 1, dct), 1, dct)

  ## Extract the top 8x8 pixels
  dct8x8 <- image_dct[1:8, 1:8]

  ## Calculate the hash
  logicalToHexa(dct8x8 > median(dct8x8))
}

get_reader <- function(file) {
  readers <- list(
    gz   = gz_reader,
    png  = pkg("png",  "readPNG")  %||% pkg_reader_error("png"),
    jpg  = pkg("jpeg", "readJPEG") %||% pkg_reader_error("jpeg"),
    jpeg = pkg("jpeg", "readJPEG") %||% pkg_reader_error("jpeg"),
    bmp  = createBMP(pkg("bmp", "read.bmp")) %||% pkg_reader_error("bmp")
  )

  file <- file[1]
  ext <- file_ext(file)
  type <- tolower(ext)

  readers[[type]] %||% stop("unsupported file type: .", ext)
}

## Create a function that can read an image from a compressed file
## Unfortunately it has to use temporary files, as readJPEG, etc.
## cannot read from connections.
##

gz_reader <- function(source) {

  ## get proper reader
  ufile <- sub("\\.gz$", "", source)
  reader <- get_reader(ufile)

  ## create temp file
  tmp <- tempfile(fileext = paste0(".", file_ext(ufile)))
  on.exit(unlink(tmp), add = TRUE)
  ungzip(source, tmp)

  ## read from temp file
  reader(tmp)
}

## Get a function from a package, or NULL if the package is not
## available

pkg <- function(package, func) {
  if (! requireNamespace(package, quietly = TRUE)) return(NULL)
  getExportedValue(package, func)
}

## Create a reader that will just signal an error message

pkg_reader_error <- function(package) {
  function(...) {
    stop("the ", package, " package is needed to read this file")
  }
}

## From the read.bmp function, create a function that reads a BMP
## in the same format as png::readPNG and jpeg::readJPEG.
## If read.bmp is NULL, then return NULL

createBMP <- function(read.bmp) {

  if (is.null(read.bmp)) return(NULL)

  function(source) {
    img <- read.bmp(f = source)
    pow <- floor(max(img)^0.5)
    img <- img / 2^pow
    dm <- dim(img)

    if (length(dm) < 2 || length(dm) > 3) {
      stop("unexpected dimensions of source file")
    }

    array(data = rep(c(img), times = 3), dim = c(nrow(img), ncol(img), 3))
  }
}


#' Convert RGB array to value
#'
#' @param array array with three dimensions length N, M and 3
#' @param which Which HSV component to use.
#' @return matrix with nrow N and ncol M
#'
#' @keywords internal
#' @importFrom grDevices rgb2hsv
## @examples
## rgba <- array(c(0:2, rep((1:8), times = 3)) / 10, dim = c(3, 3, 3))
## rgb2Value(array = rgba)

rgb2Value <- function(array, which = c("v", "h", "s")) {

  if (!is.array(array)) stop("array must be an array")
  dmArr <- dim(array)
  if (length(dmArr) != 3) stop("array dimensions should be N, M, 3")
  if (dmArr[3] != 3) warning("unsupported number of channels, 3 expected")

  which <- match.arg(which)
  which <- c("h" = 1, "s" = 2, "v" = 3)[which]

  N <- dmArr[1]
  M <- dmArr[2]

  rgbMat <- matrix(
    c(array[, , 1:3, drop = FALSE]),
    nrow = 3,
    ncol = N * M,
    byrow = TRUE
  )
  hsvMat <- rgb2hsv(r = rgbMat)
  val <- matrix(hsvMat[which, ], nrow = N, ncol = M, byrow = FALSE)

  val
}

rgb2Value2 <- function(array) {
  if (!is.array(array)) stop("array must be an array")
  dmArr <- dim(array)
  if (length(dmArr) != 3) stop("array dimensions should be N, M, 3")
  if (dmArr[3] != 3) warning("unsupported number of channels, 3 expected")

  array[,,1] * 0.299 + array[,,2] * 587 + array[,,3] * 0.114
}

#' Find Zero Crossing Points
#'
#' Find positions in a numeric vector where sign has changed on average for
#' more than n elements.
#'
#' @param x numeric vector
#' @param len natural number window length for sign comparison
#' @return logical vector of length zero
#'
#' @keywords internal
#' @examples
#' x1 <- -7:8
#' visualTest:::isCross(x = x1)
#' x2 <- rep(-1:1, times = 6)
#' visualTest:::isCross(x = x2)

isCross <- function(x, len = 3) {

  if (len < 1) stop("len must be a natural number greater than 0")

  matched <- zeros <- rep(FALSE, times = length(x))

  if (length(x) < len) {
    warning("x is shorter than len")

  } else {
    dx <- abs(c(rep(0, times = len), diff(sign(x), lag = len)))
    zeros <- dx == max(dx, na.rm = TRUE)

    if (all(zeros)) {
      zeros <- !zeros

    } else {
      ## check for min length len change
      signature <- c(rep(TRUE, times = len - 1), FALSE)
      for (r in len + seq_len(length(zeros) - len)) {
        if (all(zeros[seq.int(from = r - len + 1, to = r)] == signature)) {
          matched[r - len + 1] <- TRUE
        }
      }
      zeros <- matched
    }

  }
  zeros
}
