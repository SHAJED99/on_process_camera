# image_cropper bundles uCrop, which references OkHttp/Okio only for its
# optional "load image from URL" feature. They aren't dependencies, so R8
# fails the release build on the missing classes. Local files never use them.
-dontwarn okhttp3.**
-dontwarn okio.**
