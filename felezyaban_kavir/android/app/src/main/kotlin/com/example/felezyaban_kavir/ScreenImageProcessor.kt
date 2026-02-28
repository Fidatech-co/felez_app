package mis.felezyaban.com

import java.io.File
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.MatOfPoint
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Size
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc

object ScreenImageProcessor {
    fun process(imagePath: String, cacheDir: File): String {
        val source = Imgcodecs.imread(imagePath)
        if (source.empty()) {
            throw IllegalArgumentException("Unable to load source image.")
        }

        val contour = findScreenContour(source)
        val warped = warpToRectangle(source, contour)
        val processed = enhanceScreen(warped)

        val output = File(cacheDir, "screen_${System.currentTimeMillis()}.png")
        Imgcodecs.imwrite(output.absolutePath, processed)

        source.release()
        contour.release()
        warped.release()
        processed.release()

        return output.absolutePath
    }

    private fun findScreenContour(image: Mat): MatOfPoint2f {
        val gray = Mat()
        val blurred = Mat()
        val edges = Mat()
        Imgproc.cvtColor(image, gray, Imgproc.COLOR_BGR2GRAY)
        Imgproc.GaussianBlur(gray, blurred, Size(5.0, 5.0), 0.0)
        Imgproc.Canny(blurred, edges, 50.0, 150.0)

        val contours = ArrayList<MatOfPoint>()
        Imgproc.findContours(edges, contours, Mat(), Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)
        contours.sortByDescending { Imgproc.contourArea(it) }

        var best: MatOfPoint2f? = null
        for (contour in contours) {
            val contour2f = MatOfPoint2f(*contour.toArray())
            val perimeter = Imgproc.arcLength(contour2f, true)
            val approx = MatOfPoint2f()
            Imgproc.approxPolyDP(contour2f, approx, 0.02 * perimeter, true)
            if (approx.total() == 4L) {
                best = approx
                contour2f.release()
                break
            }
            contour2f.release()
            approx.release()
        }

        contours.forEach { it.release() }
        gray.release()
        blurred.release()
        edges.release()

        return best ?: MatOfPoint2f(
            Point(0.0, 0.0),
            Point(image.cols() - 1.0, 0.0),
            Point(image.cols() - 1.0, image.rows() - 1.0),
            Point(0.0, image.rows() - 1.0),
        )
    }

    private fun warpToRectangle(image: Mat, contour: MatOfPoint2f): Mat {
        val ordered = orderPoints(contour)
        val destination = MatOfPoint2f(
            Point(0.0, 0.0),
            Point(799.0, 0.0),
            Point(799.0, 599.0),
            Point(0.0, 599.0),
        )

        val matrix = Imgproc.getPerspectiveTransform(ordered, destination)
        val warped = Mat(Size(800.0, 600.0), image.type())
        Imgproc.warpPerspective(image, warped, matrix, warped.size())

        ordered.release()
        destination.release()
        matrix.release()

        return warped
    }

    private fun enhanceScreen(warped: Mat): Mat {
        val gray = Mat()
        Imgproc.cvtColor(warped, gray, Imgproc.COLOR_BGR2GRAY)
        Imgproc.GaussianBlur(gray, gray, Size(3.0, 3.0), 0.0)
        Imgproc.threshold(gray, gray, 0.0, 255.0, Imgproc.THRESH_BINARY or Imgproc.THRESH_OTSU)

        val oriented = fixOrientation(gray)
        val resized = Mat()
        Imgproc.resize(oriented, resized, Size(800.0, 600.0), 0.0, 0.0, Imgproc.INTER_AREA)
        oriented.release()

        return resized
    }

    private fun fixOrientation(base: Mat): Mat {
        val candidates = mutableListOf<Mat>()
        val scores = mutableListOf<Double>()

        candidates.add(base)
        scores.add(horizontalScore(base))

        val rotated90 = Mat()
        Core.rotate(base, rotated90, Core.ROTATE_90_CLOCKWISE)
        candidates.add(rotated90)
        scores.add(horizontalScore(rotated90))

        val rotated180 = Mat()
        Core.rotate(base, rotated180, Core.ROTATE_180)
        candidates.add(rotated180)
        scores.add(horizontalScore(rotated180))

        val rotated270 = Mat()
        Core.rotate(base, rotated270, Core.ROTATE_90_COUNTERCLOCKWISE)
        candidates.add(rotated270)
        scores.add(horizontalScore(rotated270))

        val bestIndex = scores.indexOf(scores.maxOrNull() ?: scores.first())
        for (i in candidates.indices) {
            if (i == bestIndex) continue
            candidates[i].release()
        }
        return candidates[bestIndex]
    }

    private fun horizontalScore(mat: Mat): Double {
        val gradY = Mat()
        Imgproc.Sobel(mat, gradY, CvType.CV_32F, 0, 1)
        val absGrad = Mat()
        Core.convertScaleAbs(gradY, absGrad)
        val sum = Core.sumElems(absGrad).`val`[0]
        gradY.release()
        absGrad.release()
        return sum
    }

    private fun orderPoints(points: MatOfPoint2f): MatOfPoint2f {
        val pts = points.toArray()
        val ordered = Array(4) { Point() }

        val sum = pts.map { it.x + it.y }
        val diff = pts.map { it.x - it.y }

        ordered[0] = pts[sum.indexOf(sum.minOrNull() ?: sum.first())]
        ordered[2] = pts[sum.indexOf(sum.maxOrNull() ?: sum.first())]
        ordered[1] = pts[diff.indexOf(diff.minOrNull() ?: diff.first())]
        ordered[3] = pts[diff.indexOf(diff.maxOrNull() ?: diff.first())]

        val tl = ordered[0]
        val tr = ordered[1]
        val bl = ordered[3]
        val cross = (tr.x - tl.x) * (bl.y - tl.y) - (tr.y - tl.y) * (bl.x - tl.x)
        if (cross < 0) {
            val temp = ordered[1]
            ordered[1] = ordered[3]
            ordered[3] = temp
        }

        return MatOfPoint2f(*ordered)
    }
}
