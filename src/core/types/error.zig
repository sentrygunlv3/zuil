pub const ZError = error{
	NotImplemented,
	// widget
	MissingWidgetFunction,
	NoWidgetData,
	// rendering
	NotSupportedByBackend,
	FailedToCompileShader,
	FailedToLinkShader,
	MissingShader,
	MissingTexture,
	// assets
	MissingAsset,
	WrongAssetType,
	// ---
	FailedToCreateSvg,

	OutOfMemory,
	updatePreferredSizeFailed,
	updateActualSizeFailed,
	updatePositionFailed,
	renderWidgetFailed,
};

pub const ZErrorC = enum(c_int) {
	noError = 0,
	OutOfMemory,
	updatePreferredSizeFailed,
	updateActualSizeFailed,
	updatePositionFailed,
	renderWidgetFailed,
};

pub fn errorFromC(e: c_int) ?ZError {
	return switch (@as(ZErrorC, @enumFromInt(e))) {
		.noError => null,
		.OutOfMemory => ZError.OutOfMemory,
		.updatePreferredSizeFailed => ZError.updatePreferredSizeFailed,
		.updateActualSizeFailed => ZError.updateActualSizeFailed,
		.updatePositionFailed => ZError.updatePositionFailed,
		.renderWidgetFailed => ZError.renderWidgetFailed,
	};
}
