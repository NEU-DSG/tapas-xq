TAPAS-xq
========

An EXPath application to manage [TAPAS](https://tapasproject.org)'s interests inside an [eXist XML database](http://exist-db.org/exist/apps/homepage/index.html).

TAPAS-xq provides an API for the [Ruby on Rails component of TAPAS](https://github.com/NEU-DSG/tapas_rails) to accomplish tasks that are easier to do in an XML-native environment. Among these tasks:

- Test that files are wellformed XML in the TEI namespace.
- Store and index TEI files.
- Generate MODS metadata for TEI files, using the `<teiHeader>` and information provided by the uploader.
- Transform TEI files into XHTML through TAPAS view packages.

TAPAS-xq also provides scripts for maintaining and updating the TAPAS view packages with the help of the GitHub and TAPAS Rails APIs.


## Setup and installation

TAPAS-xq must be installed into a copy of the eXist database. To figure out which version(s) of eXist can be used with TAPAS-xq, check the `<dependency>` entry in [expath-pkg.xml](./expath-pkg.xml).

Installation packages for eXist can be found on the [releases page](https://github.com/eXist-db/exist/releases) of the eXist-db GitHub repository. The eXist documentation has a useful [guide on installation](http://exist-db.org/exist/apps/doc/basic-installation).

In a local development environment, eXist doesn't need much in the way of configuration. In `EXIST_HOME/etc/conf.xml`, these settings are recommended (though not essential):

- On `<indexer>`, set `preserve-whitespace-mixed-content` to "yes".
- On `<serializer>`, set `indent` to "no".
- Inside `<transformer class="net.sf.saxon.TransformerFactoryImpl">`, add the following element:

```xml
<attribute name="http://saxon.sf.net/feature/strip-whitespace"
           value="none"
           type="string" />
```

The settings listed above are helpful because they prevent eXist (and the Saxon XSLT processor) from adding or removing whitespace within XML. Since whitespace is likely to be significant in mixed content TEI documents, TAPAS must take steps to ensure that the text content of files is retained after upload.

<!-- For a full list of eXist configurations used in the development and production environments, please see the TAPAS server documentation. -->

Once `conf.xml` has been edited and saved, you can start (or re-start) eXist. To start eXist from the command line, run `./bin/startup.sh` from the eXist home directory. You can then shut down eXist by hitting the <kbd>Control</kbd> and <kbd>C</kbd> keys to interrupt the process. (You may also be able to start eXist through your operating system's application menu.)


### Deploying TAPAS-xq into eXist

First, you'll need a copy of the TAPAS-xq XAR file. The [latest stable TAPAS-xq package](https://github.com/NEU-DSG/tapas-xq/releases/latest) can be found in the GitHub repository. 

Alternatively, you can clone the repository, and run the Ant build file to [generate the XAR file locally](#generating-a-xar-package).


#### Installing the XAR file

In your browser, navigate to eXist's Dashboard at [localhost:8080/exist/apps/dashboard/index.html](http://localhost:8080/exist/apps/dashboard/index.html).

Log in as the "admin" user. Once you've done so, a sidebar will appear on the left. Select "Package Manager" from the sidebar, then click the "Upload" button. A file upload window will appear where you can select the TAPAS-xq XAR file. Click "Open" to upload the package and install it.

The Package Manager will display an animation as it processes the package. When it has finished, TAPAS-xq will appear as an application in your list of installed packages.


#### Configure eXist-to-Rails communication

TAPAS-xq uses `tapas_rails`'s View Packages API to decide which view packages should be installed from GitHub. You may need to change "environment.xml" to match the URL for Rails. When you install TAPAS-xq for the first time, it will place a copy of the configuration file in the "/db" collection.

If you've already installed TAPAS-xq (or plan to do so with a XAR from GitHub), you may need to make tweaks post-installation. Subsequent reinstalls will not modify the configuration file; you will need to upload a new version or make edits via eXist's web editor eXide.

Currently, the default setting for the Rails URL is:

    <railsBaseURI>http://127.0.0.1:3000</railsBaseURI>

This should work for local development.

If you have _not_ installed TAPAS-xq yet, you can make any edits directly to the copy of [environment.xml](./environment.xml) stored in this repository, then (re)build the XAR package using the instructions above.

A plattr-specific configuration file is available at "environment.xml.plattr".


#### Update view packages

With eXist-to-Rails communication set and Rails running, you can tell TAPAS-xq to download the [view packages](https://github.com/NEU-DSG/tapas-view-packages) from GitHub by making a request to TAPAS-xq as either the admin or tapas user. For example, `curl -u tapas http://localhost:8080/exist/rest/db/apps/tapas-xq/modules/update-view-packages.xq`.


## Contributing

<!-- ... -->

### Generating a XAR package

Run [Apache Ant](https://ant.apache.org/manual/running.html) from within your local repo. By default, Ant will build a zipped archive from files within the repository, and store the new package in the (git-ignored) `build` directory.

In the terminal:

```
git clone https://github.com/NEU-DSG/tapas-xq.git
cd tapas-xq
ant
```

You can also see the current semantic version of TAPAS-xq with the command `ant version`.


***

## Hungry for more TAPAS?

[TAPAS website](https://tapasproject.org/)

[TAPAS Rails repository](https://github.com/NEU-DSG/tapas_rails)

[TAPAS view packages repository](https://github.com/NEU-DSG/tapas-view-packages)

[TAPAS public documents, documentation, and meeting notes](https://github.com/NEU-DSG/tapas-docs)
