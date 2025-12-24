pub const UError = error{
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
