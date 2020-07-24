.PHONY: build clean publish

TASKCAT_OPTIONS ?=
VERSION ?=
BUCKET ?=
REGION ?=
PREFIX ?= quickstart-amazon-eks
PROFILE ?= default
GH_RELEASE ?= false
PART ?= patch
BUILD_FUNCTIONS ?= true

build:
	mkdir -p output/build/functions
	if [ "$(BUILD_FUNCTIONS)" == "true" ] ; then \
	  build/lambda_package.sh ; \
	fi
	cp -r functions/packages output/build/functions/
	cp -r scripts templates submodules output/build
	cp -r LICENSE.txt NOTICE.txt output/build
	if [ "$(VERSION)" != "" ] ; then \
	  sed -i "s|Default: $(PREFIX)/|Default: $(PREFIX)-versions/$(VERSION)/|g" output/build/templates/*.yaml ; \
	fi
	if [ "$(BUCKET)" != "" ] ; then \
	  sed -i "s/UsingDefaultBucket: \!Equals \[\!Ref QSS3BucketName, 'aws-quickstart'\]/UsingDefaultBucket: \!Equals [\!Ref QSS3BucketName, \'$(BUCKET)\']/" output/build/templates/*.yaml ; \
	  sed -i "s/Default: aws-quickstart/Default: $(BUCKET)/" output/build/templates/*.yaml ; \
	fi
	if [ "$(REGION)" != "" ] ; then \
	  sed -i "s/Default: 'us-east-1'/Default: \'$(REGION)\'/" output/build/templates/*.yaml ; \
	fi
	cd output/build/ && \
	find . -exec touch -t 202007010000.00 {} + && \
	zip -X -r ../release.zip .

publish:
	if [ "$(BUCKET)" == "" ] ; then \
      echo BUCKET must be specified to publish; exit 1; \
    fi
	if [ "$(REGION)" == "" ] ; then \
      echo REGION must be specified to publish; exit 1; \
    fi
	if [ $(shell echo $(VERSION) | grep -c dev) -eq 0 ] ; then \
		if [ "$(GH_RELEASE)" == "true" ] ; then \
			hub release create -m v$(VERSION) -a "output/release.zip#$(PREFIX)-s3-package-v$(VERSION).zip" v$(VERSION) ;\
		fi ; \
	fi
	if [ "$(VERSION)" == "" ] ; then \
		cd output/build && aws s3 sync --delete --size-only --profile $(PROFILE) --region $(REGION) ./ s3://$(BUCKET)/$(PREFIX)/ ; \
	else \
	    cd output/build && aws s3 sync --delete --size-only --profile $(PROFILE) --region $(REGION) ./ s3://$(BUCKET)/$(PREFIX)-versions/$(VERSION)/ ; \
	fi

clean:
	rm -rf output/
	rm -rf taskcat_outputs
	rm -rf .taskcat
	rm -rf functions/packages
