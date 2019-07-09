TAPAS-xq
=======

An EXPath application to manage TAPAS's interests inside eXist-db, including generation of the HTML/MODS from TEI.

## Installation
It's assumed you have eXist-db up and running somewhere. If not, see the [eXist Quick Start](http://exist-db.org/exist/apps/doc/quickstart.xml) guide and follow the instructions there.

You'll want to be logged in on the machine where you've installed eXist. [Plattr](https://github.com/NEU-DSG/plattr) users should SSH into their Vagrant box.

### Get a copy
Clone down this repository using your git client of choice, then run [Apache Ant](https://ant.apache.org/manual/running.html) from within your local repo. By default, Ant will build a zipped archive from files within the repository, and store the new package in the (git-ignored) `build` directory.

In the terminal:

1. `git clone https://github.com/NEU-DSG/tapas-xq.git`

2. `cd tapas-xq`

3. `ant`

You can also see the current semantic version of TAPAS-xq with `ant version`.

Alternatively, get the latest XAR file from GitHub: <https://github.com/NEU-DSG/tapas-xq/releases>.

### Deploy the app
#### Installing the XAR file
In your browser, navigate to eXist's Dashboard interface. The default URL is <http://localhost:8080/exist>. Those using Plattr should try <http://localhost:8848/exist> instead.

Log in as the admin user. (Plattr users: the default password is "dsgT@pas".) Click on the icon labeled "Package Manager" and then again on the cylinder in the top-left corner.

Either drag-and-drop the `.xar` file into the new window, or click on the button to choose the file from a menu.

<!-- There are lots of ways to get packages into eXist: -->
<!-- #### With the Java Admin Client (I think?) -->
<!-- #### By auto-deploying -->
<!-- #### With XQuery -->
<!-- http://exist-db.org/exist/apps/doc/repo.xml -->

#### Configure eXist-to-Rails communication
TAPAS-xq uses tapas_rails's View Packages API to decide which view packages should be installed from GitHub. You may need to change "environment.xml" to match the URL for Rails. When you install TAPAS-xq for the first time, it will place a copy of the configuration file in the "/db" collection. Subsequent reinstalls will not modify the file; you will need to upload a new version or make edits via eXist's web editor eXide.

Currently, the default setting for the Rails URL is:

    &lt;railsBaseURI>http://127.0.0.1:3000&lt;/railsBaseURI>

This should work for local development.

If you've already installed TAPAS-xq (or plan to do so with a XAR from GitHub), you'll need to make post-installation changes by editing the file at "/db/environment.xml".

If you have _not_ installed TAPAS-xq yet, you can make any edits directly to the copy of [environment.xml](./environment.xml) stored in this repository, then (re)build the XAR package using the instructions above.

A plattr-specific configuration file is available at "environment.xml.plattr".

#### Update view packages

With eXist-to-Rails communication set and Rails running, you can tell TAPAS-xq to download the view packages from GitHub by making a request to TAPAS-xq as either the admin or tapas user. For example, `curl -u tapas http://localhost:8080/exist/rest/db/apps/tapas-xq/modules/update-view-packages.xq`.


## Hungry for more TAPAS?
[TAPAS website](http://www.tapasproject.org/)

[TAPAS public documents, documentation, and meeting notes on GitHub](https://github.com/NEU-DSG/tapas-docs)

[TAPAS Drupal theme on GitHub](https://github.com/NEU-DSG/tapas-themes)

[TAPAS Drupal modules on GitHub](https://github.com/NEU-DSG/tapas-modules)

[TAPAS Hydra Head on GitHub](https://github.com/NEU-DSG/tapas_rails)

[TAPAS virtual machine provisioning on GitHub](https://github.com/NEU-DSG/plattr)
