TAPAS-xq
========

TAPAS-xq is an EXPath application to manage [TEI](https://tei-c.org/)-encoded resources in an XML database. TAPAS-xq provides an API for the [Ruby on Rails component of TAPAS](https://github.com/NEU-DSG/tapas_rails) to accomplish tasks that are easier to do in an XML-native environment. Among these tasks:

- Test that files are wellformed XML in the TEI namespace.
- Store and index TEI files.
- Generate MODS metadata for TEI files, using the `<teiHeader>` and information provided by the uploader.
- Transform TEI files into XHTML through TAPAS view packages.

TAPAS-xq also provides scripts for maintaining and updating the TAPAS view packages with the help of the GitHub and TAPAS Rails APIs.

## Table of Contents

- [Setup and installation](#setup-and-installation)
  - [Setting up BaseX](#setting-up-basex)
  - [Deploying TAPAS-xq](#deploying-tapas-xq)
    - [Installing the XAR file](#installing-the-xar-file)
    - [Configuring communication with TAPAS Rails](#configuring-communication-with-tapas-rails)
  - [Updating view packages](#updating-view-packages)
- [Contributing](#making-changes-to-tapas-xq)
  - [Generating a XAR package](#generating-a-xar-package)
- [Hungry for more TAPAS?](#hungry-for-more-tapas)


## Setup and installation

### Setting up BaseX

TAPAS-xq is designed to run in [BaseX](https://basex.org/), an open source XML database engine. [Download either the ZIP or WAR package](https://basex.org/download/) of BaseX, at version 10 or higher.

If using the BaseX ZIP, unpack the archive and place the directory wherever you'd like.

If using the BaseX WAR, place the web archive in the `webapps` directory of [Apache Tomcat](https://tomcat.apache.org/). Then, start Tomcat in order to unpack the archive.

To make full use of TAPAS-xq, you will need to configure BaseX further:

- Enable XSLT 3.0 transformation
- Require authentication through BaseX

#### Enable XSLT 3.0

BaseX will allow XSL 3.0 transformations if it finds a [Saxon processor](https://www.saxonica.com) on the classpath.

To set this up, [download the latest Saxon HE package](https://www.saxonica.com/download/java.xml) and unpack it. Place the extracted directory into `BASEX/lib/custom` (ZIP installation) or `BASEX/lib` (WAR installation). You'll need to restart BaseX so that it registers the library.

To make sure you've installed Saxon HE correctly, navigate to `BASE-URL/dba/queries` in your browser, and run `xslt:processor()`. You should see the result "Saxon HE", not "Java".

#### Require authentication




### Deploying TAPAS-xq

First, you'll need a copy of the TAPAS-xq XAR file. The [latest stable TAPAS-xq package](https://github.com/NEU-DSG/tapas-xq/releases/latest) can be found in the GitHub repository. 

Alternatively, you can create a XAR file on your own computer. To do that, clone this repository and run the Ant build file to generate the XAR file. (See the [XAR generation section](#generating-a-xar-package) below for instructions.)


#### Installing the XAR file




#### Configuring communication with TAPAS Rails

TAPAS-xq uses `tapas_rails`'s View Packages API to decide which view packages should be installed from GitHub. You may need to change "environment.xml" to match the URL for Rails. <!--When you install TAPAS-xq for the first time, it will place a copy of the configuration file in the "/db" collection.-->

Currently, the default setting for the Rails URL is:

```xml
<railsBaseURI>http://127.0.0.1:3000</railsBaseURI>
```

This should work if you have TAPAS Rails running on your own computer.


### Updating view packages

With Rails communication set and Rails running, you can tell TAPAS-xq to download the [view packages](https://github.com/NEU-DSG/tapas-view-packages) from GitHub by making a request to TAPAS-xq as either the admin or tapas user. For example: 

```shell
curl -u tapas http://localhost:8080/tapas-xq/modules/update-view-packages.xq
```


## Making changes to TAPAS-xq

<!-- ... -->

### Generating a XAR package

Run [Apache Ant](https://ant.apache.org/manual/running.html) from within your local repo. By default, Ant will build a zipped archive from files within the repository, and store the new package in the (git-ignored) `build` directory.

In the terminal:

```shell
cd tapas-xq
ant
```

You can also see the current semantic version of TAPAS-xq with the command `ant version`.


***

## Hungry for more TAPAS?

[TAPAS website](https://tapasproject.org/)

[TAPAS Rails repository](https://github.com/NEU-DSG/tapas_rails)

[TAPAS View Packages repository](https://github.com/NEU-DSG/tapas-view-packages)

[Public documents, documentation, and meeting notes for TAPAS](https://github.com/NEU-DSG/tapas-docs)
