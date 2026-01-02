pub const ZError = error{
	NotImplemented,
	NoWindowsCreated,
	// widget
	MissingWidgetFunction,
	NoWidgetData,
	// shader
	FailedToCompileShader,
	FailedToLinkShader,
	MissingShader,
	// assets
	MissingAsset,
	WrongAssetType,
	// ---
	FailedToCreateSvg
};
