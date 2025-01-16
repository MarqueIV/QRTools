import CoreImage
import CoreImage.CIFilterBuiltins

@available(macOS 10.15, iOS 13.0, *)
public struct QRCodeInfo {

	public enum CorrectionLevel: String {
		case low      = "L"
		case medium   = "M"
		case quartile = "Q"
		case high     = "H"
	}

	public enum Error: LocalizedError {

		case emptyValue
		case failedToGetPixelBuffer

		public var errorDescription: String? {
			switch self {
				case .emptyValue: "Value cannot be empty."
				case .failedToGetPixelBuffer: "Failed to get pixel buffer."
			}
		}
	}

	public init(value: String, correctionLevel: CorrectionLevel = .medium) throws {

		guard value.isEmpty == false else {
			throw Error.emptyValue
		}

		// Create a QR code generator filter
		let filter = CIFilter.qrCodeGenerator()
		filter.correctionLevel = correctionLevel.rawValue
		filter.message = Data(value.utf8)

		// Get bitmap representation
		let context = CIContext()
		guard let rawImage = filter.outputImage,
			let cgImage = context.createCGImage(rawImage, from: rawImage.extent),
			let pixelBuffer = cgImage.dataProvider?.data as Data?
		else {
			throw Error.failedToGetPixelBuffer
		}

		// Extract pixel data and build up the path
		// Note: We are manually trimming off a 1-px border, hence the adjustments and inclusive ranges

		self.rows    = cgImage.height - 2
		self.columns = cgImage.width - 2

		// Process each pixel (QR code is black-and-white only)
		// We use scaleTransform to make the resulting path fit within a unit bounds (1x1)
		// This way the target can scale it to whatever size they want for display/print, etc.
		// e.g. a 32x32 QR Code will have 'pixels' that are sized as 1/32x1/32
		var bits           = [Bool](repeating: false, count: rows * columns)
		var bitIndex       = 0
		let cgPath         = CGMutablePath()
		let scaleTransform = CGAffineTransform(scaleX: 1.0/CGFloat(columns), y: 1.0/CGFloat(rows))

		for y in 1..<cgImage.height - 1 {
			for x in 1..<cgImage.width - 1 {
				let pixelIndex = (y * cgImage.width + x)
				let isBitSet = pixelBuffer[pixelIndex * 4] == 0 // Multiply by four for RGBA components. Black pixel is `true`
				if isBitSet {
					bits[bitIndex] = true
					let bitRect = CGRect(x: x - 1, y: y - 1, width: 1, height: 1) // Adjust for cropping
					cgPath.addRect(bitRect, transform: scaleTransform)
				}
				bitIndex += 1
			}
		}

		self.bits    = bits
		self.cgImage = cgImage.cropping(to: .init(x: 1, y: 1, width: columns, height: rows))!
		self.cgPath  = cgPath
	}

	public let rows:    Int
	public let columns: Int
	public let bits:    [Bool]
	public let cgImage: CGImage
	public let cgPath:  CGPath

	public subscript(row: Int, column: Int) -> Bool {
		bits[row * columns + column]
	}
}
