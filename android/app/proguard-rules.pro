# google_mlkit_text_recognition's Android plugin references every script model
# (Chinese, Devanagari, Japanese, Korean) even though Folio only ever asks for
# the Latin recognizer. Only the Latin artifact is on the classpath, so R8 fails
# the release build on the others. Suppressing the warnings keeps the unused
# models out of the APK instead of pulling in several megabytes of recognizers
# that would never run.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
