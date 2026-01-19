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
	FailedToCreateSvg
};
