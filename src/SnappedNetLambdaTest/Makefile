#please be aware of spacing issue(<TAB> is required!!!): https://stackoverflow.com/questions/29972396/how-can-i-customize-the-tab-to-space-conversion-factor-in-vs-code 
build-HelloWorldFunction:
  dotnet build -c Release src/SnappedNetLambdaTest/SnappedNetLambdaTest.csproj --output ./target
	rm -rf ./target/runtimes
	cp -v ./target/* $(ARTIFACTS_DIR)/
  