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
};
