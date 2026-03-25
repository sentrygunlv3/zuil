pub const ZError = error{
	NotImplemented,
	// widget
	MissingWidgetFunction,
	NoChildFound,
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
	CError,
};
