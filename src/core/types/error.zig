pub const ZError = error{
	NotImplemented,
	NoWindowsCreated,
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
