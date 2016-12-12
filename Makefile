.PHONY: clean-pyc clean-build clean-patch clean-local docs clean help lint \
	    test test-all coverage docs release dist tags install \
		build-release pre-release freeze-release _tag-release upload-release \
		pypi-release github-release
SRC_DIRS = nicfit
define BROWSER_PYSCRIPT
import os, webbrowser, sys
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT
BROWSER := python -c "$$BROWSER_PYSCRIPT"
GIT := git -c user.name="$(NAME)" -c user.email="$(EMAIL)"
PYPI_REPO = pypitest

help:
	@echo "test - run tests quickly with the default Python"
	@echo "docs - generate Sphinx HTML documentation, including API docs"
	@echo "clean - remove all build, test, coverage and Python artifacts"
	@echo "clean-build - remove build artifacts"
	@echo "clean-pyc - remove Python file artifacts"
	@echo "clean-test - remove test and coverage artifacts"
	@echo "clean-patch - remove patch artifacts (.rej, .orig)"
	@echo "lint - check style with flake8"
	@echo "coverage - check code coverage quickly with the default Python"
	@echo "test-all - run tests on various Python versions with tox"
	@echo "release - package and upload a release"
	@echo "          PYPI_REPO=[pypitest]|pypi"
	@echo "pre-release - check repo and show version"
	@echo "dist - package"
	@echo "install - install the package to the active Python's site-packages"
	@echo ""
	@echo "Options:"
	@echo "TEST_PDB - If defined PDB options are added when 'pytest' is invoked"

	@echo "BROWSER - Set to empty string to prevent opening docs/coverage results in a web browser"

clean: clean-local clean-build clean-pyc clean-test clean-patch
	rm -rf tags

clean-local:
	-rm *.log
	@# XXX Add new clean targets here.

clean-build:
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

clean-pyc:
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +

clean-test:
	rm -fr .tox/
	rm -f .coverage

clean-patch:
	find . -name '*.rej' -exec rm -f '{}' \;
	find . -name '*.orig' -exec rm -f '{}' \;

lint:
	flake8 $(SRC_DIRS)


_PYTEST_OPTS=
ifdef TEST_PDB
    _PDB_OPTS=--pdb -s
endif

test:
	pytest $(_PYTEST_OPTS) $(_PDB_OPTS) ./tests

test-all:
	tox

coverage:
	pytest --cov=nicfit --cov-report=html --cov-report term \
		   --cov-config=setup.cfg ./tests

docs:
	rm -f docs/nicfit.py.rst
	rm -f docs/modules.rst
	sphinx-apidoc -o docs/ nicfit
	$(MAKE) -C docs clean
	$(MAKE) -C docs html
	@if test -n '$(BROWSER)'; then \
	    $(BROWSER) docs/_build/html/index.html;\
	fi

servedocs: docs
	watchmedo shell-command -p '*.rst' -c '$(MAKE) -C docs html' -R -D .

pre-release: test
	$(eval VERSION = $(shell python setup.py --version 2> /dev/null))
	@echo "VERSION: $(VERSION)"
	$(eval RELEASE_TAG = v${VERSION})
	@echo "RELEASE_TAG: $(RELEASE_TAG)"
	$(eval RELEASE_NAME = $(shell python setup.py --release-name 2> /dev/null))
	@echo "RELEASE_NAME: $(RELEASE_NAME)"
	git authors --list >| AUTHORS
	# FIXME: changelog update

build-release: test-all dist

freeze-release:
	@($(GIT) diff --quiet && $(GIT) diff --quiet --staged) || \
		(printf "\n!!! Working repo has uncommited/unstaged changes. !!!\n" && \
		 printf "\nCommit and try again.\n" && false)

_tag-release:
	$(GIT) tag -a $(RELEASE_TAG) -m "Release $(RELEASE_TAG)"
	$(GIT) push --tags origin

release: freeze-release pre-release build-release _tag-release upload-release

github-release: pre-release
	name="${RELEASE_TAG}"; \
    if test -n "${RELEASE_NAME}"; then \
        name="${RELEASE_TAG} (${RELEASE_NAME})"; \
    fi; \
    prerelease=""; \
    if echo "${RELEASE_TAG}" | grep '[^v0-9\.]'; then \
        prerelease="--pre-release"; \
    fi; \
    echo "NAME: $$name"; \
    echo "PRERELEASE: $$prerelease"; \
    github-release --verbose release --user "${GITHUB_USER}" --repo nicfit.py \
                   --tag ${RELEASE_TAG} --name "$${name}" $${prerelease}
	# TODO               --description "$$(cat README.rst)" --draft
	for file in $$(find dist -type f -exec basename {} \;) ; do \
        echo "FILE: $$file"; \
        github-release upload --user "${GITHUB_USER}" --repo nicfit.py \
                   --tag ${RELEASE_TAG} --name $${file} --file dist/$${file}; \
    done
	# TODO: Upload md5sums

upload-release: github-release pypi-release

pypi-release:
	find dist -type f -exec twine register -r ${PYPI_REPO} {} \;
	find dist -type f -exec twine upload -r ${PYPI_REPO} {} \;

dist: clean
	python setup.py sdist
	python setup.py bdist_wheel
	ls -l dist

install: clean
	python setup.py install

tags:
	ctags -R ${SRC_DIRS}
