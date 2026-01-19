pub const ZError = error{
	NotImplemented,
	// widget
	MissingWidgetFunction,
	NoWidgetData,
	// rendering
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
