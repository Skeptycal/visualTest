<!-- -*- mode: markdown -*- -->



# visualTest

[![Linux Build Status](https://travis-ci.org/MangoTheCat/visualTest.svg?branch=master)](https://travis-ci.org/MangoTheCat/visualTest)
[![Windows Build status](https://ci.appveyor.com/api/projects/status/github/MangoTheCat/visualTest?svg=true)](https://ci.appveyor.com/project/gaborcsardi/visualTest)
[![](http://www.r-pkg.org/badges/version/visualTest)](http://www.r-pkg.org/pkg/visualTest)
[![CRAN RStudio mirror downloads](http://cranlogs.r-pkg.org/badges/visualTest)](http://www.r-pkg.org/pkg/visualTest)
[![Coverage Status](https://img.shields.io/codecov/c/github/MangoTheCat/visualTest/master.svg)](https://codecov.io/github/MangoTheCat/visualTest?branch=master)

> R package to perform fuzzy comparison of images. The threshold argument
> allows the level of fuzziness to be compared.

## Installation

Until `visualTest` gets on CRAN, you can install it directly from
GitHub with

```r
source("https://install-github.me/mangothecat/visualTest")
```

## Usage

Call `getFingerprint` to calculate a fingerprint of an image file.
You can then use `compareWithFingerprint` to compare it to the
fingerprint of another file. Visually similar files will result
similar fingerprints.

![](/inst/mango.png) ![](/inst/mango2.png)


```r
library(visualTest)
getFingerprint("mango.png")
```

```
#> [1] "FAB5894A8C963369"
```

```r
getFingerprint("mango2.png")
```

```
#> [1] "FAB5894A8C963369"
```

![](/inst/cat.jpg)


```r
getFingerprint("cat.jpg")
```

```
#> [1] "FA85C13A9865BCCA"
```

To use `visualTest` in your test cases, you can store the fingerprint
of the desired image, and then compare that to the one generated in
the test case.

Because various platforms generate slightly different images,
you might need to allow some bits to change when you compare the image
to the fingerprint. The default fingerprint is 64 bits long, and
here we allow a mismatch of 8 bits:


```r
tmp <- tempfile(fileext = ".png")

pairs(iris[1:4], main = "Anderson's Iris Data -- 3 species",
      pch = 21, bg = c("red", "green3", "blue")[unclass(iris$Species)])
```

![plot of chunk unnamed-chunk-3](inst/unnamed-chunk-3-1.png) 

```r
dev.copy(png, tmp)
dev.off()
```


```r
isSimilar(tmp, "BA68E7B3948C8936", threshold = 8)
```

```
#> [1] TRUE
```

## License

GPL 2 © [Mango Solutions](https://github.com/mangothecat).
