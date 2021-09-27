build:
	@ruby script.rb

zip:
	@cd target/codelist && zip -q9r ../codelists.zip *