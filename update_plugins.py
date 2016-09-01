#! /usr/bin/python

# Script to update Jenkins plugins

import argparse
import os
import urllib2

#----------------------------------------------------------------------------

update_center_url = "http://updates.jenkins-ci.org/stable/"
file_name = "plugins.txt"
remove_plugins = False

#----------------------------------------------------------------------------

def remove_unwritten_files(written_files):
    "Remove plugin files not written in this update"
    for plugin_file in os.listdir(os.path.join("ref", "plugins")):
        plugin_file_path = os.path.join("ref", "plugins", plugin_file)
        if plugin_file_path not in written_files:
            os.system("git rm " + plugin_file_path)

#----------------------------------------------------------------------------

def update_plugins(args):
    "Read plugin-name:version to be checked - use 'latest' to get latest version, no version means latest and pin"
    files_written = []
    with open(args.file_name) as plugins:
        for plugin_definition in plugins:
            plugin_definition = plugin_definition.strip()
            if ":" in plugin_definition:
                name, version = plugin_definition.split(":")
                # http://updates.jenkins-ci.org/download/plugins/analysis-core/1.74/analysis-core.hpi
            else:
                name = plugin_definition
                version = None # Use latest, and pin this version
                # http://updates.jenkins-ci.org/latest/analysis-core.hpi
            if version == None:
                plugin_version = "latest"
            else:
                plugin_version = version
            if plugin_version == "latest":
                plugin_url = args.url + "/latest/" + name + ".hpi"
            else:
                plugin_url = args.url + "/download/plugins/" + name + "/" + plugin_version + "/" + name + ".hpi"
            destination_file = os.path.join("ref", "plugins", name + ".jpi")
            print("Downloading " + name + ":" + plugin_version)
            plugin_request = urllib2.Request(plugin_url)
            tmp_file = destination_file + ".tmp"
            try:
		with open(tmp_file, "w") as dest:
		    dest.write(urllib2.urlopen(plugin_request).read())
		os.rename(tmp_file, destination_file)
		files_written.append(destination_file)
            except:
                os.remove(tmp_file)
                print("Did not download " + destination_file)
            if version == None:
                pin_file = destination_file + ".pinned"
                with open(pin_file, "w") as pin:
                    pin.write("")
                    files_written.append(pin_file)
    if args.remove:
        remove_unwritten_files(files_written)

#----------------------------------------------------------------------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Update Jenkins plugins')
    parser.add_argument('-f', '--file-name', dest='file_name',
                        default=file_name,
                        help='Definition file to read (' + file_name + ')')

    parser.add_argument('--no-remove', dest='remove', action='store_false',
                        help="don't remove unreferenced plugins (default)")
    parser.add_argument('-r', '--remove', dest='remove', action='store_true',
                        help="remove unreferenced plugins")
    parser.set_defaults(remove=False)

    parser.add_argument('-u', '--update-center-url', dest='url',
                        default=update_center_url,
                        help='Update center URL (' + update_center_url + ')')

    args = parser.parse_args()
    update_plugins(args)
    exit(0)
