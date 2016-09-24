import hudson.model.*
def pattern = ~/\d+/

updateBuildNumber(Hudson.instance.items)

def updateBuildNumber(items) {
  for (item in items) {
    try {
      if (item.class.canonicalName != "com.cloudbees.hudson.plugins.folder.Folder") {
        println("check buildNumber for " + item.name + " current nextBuildNumber: " + item.getNextBuildNumber() + " buildDir: " + item.getBuildDir() + " rootDir: " + item.getRootDir())
        def max = 0
        try {
          item.getBuildDir().eachDirMatch(pattern) { dir ->
            tmpmax = dir.getPath().replace(item.getBuildDir().getAbsolutePath()+"/", "").toInteger()
            if (tmpmax > max ) {
              max = tmpmax
            }
          }
          fromFSnextBuildNumber = max + 1
          println("\tupdating nextBuildNumber to " + fromFSnextBuildNumber + " found in buildDir: " + item.getBuildDir())
          item.updateNextBuildNumber(fromFSnextBuildNumber)
	  item.save()
        } 
        catch(FileNotFoundException e) {
          println("\tnon-existing lastBuild for " + item.name + " in buildDir: " +  item.getBuildDir() + " skipping update...")
        }
      } 
      else {
        updateBuildNumber(((com.cloudbees.hudson.plugins.folder.Folder) item).getItems())
      }
    }
    catch(Exception e) {
      println("Exception:" + e.message)
    }
  }
}
