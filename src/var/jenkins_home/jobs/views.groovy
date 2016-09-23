listView('1.1.bld-loc') { 
  description('Build stage')
  recurse(true)
  jobs { 
    regex('.*build.*') 
  } 
}

listView('1.2.dev-loc') {
  description('Development deployment stage - localhost')
  recurse(true)
  jobs {
    regex('.*dev-loc.*')
  }
}

listView('1.2.rel-loc') {
  description('Release deployment stage - localhost')
  recurse(true)
  jobs {
    regex('.*rel-loc.*')
  }
}

listView('2.1.dev-pub') {
  description('Development deployment stage - public')
  recurse(true)
  jobs {
    regex('.*dev-pub.*')
  }
}

listView('2.2.rel-pub') {
  description('Release deployment stage - public')
  recurse(true)
  jobs {
    regex('.*rel-pub.*')
  }
}

listView('2.3.dem-pub') {
  description('Demo deployment stage - public')
  recurse(true)
  jobs {
    regex('.*dem-pub.*')
  }
}

listView('3.1.dev-sec') {
  description('Development deployment stage - secure')
  recurse(true)
  jobs {
    regex('.*dev-sec.*')
  }
}

listView('3.2.rel-sec') {
  description('Release deployment stage - secure')
  recurse(true)
  jobs {
    regex('.*rel-sec.*')
  }
}

listView('3.3.int-sec') {
  description('Integration deployment stage - confidential')
  recurse(true)
  jobs {
    regex('.*int-sec.*')
  }
}

listView('3.4.tst-sec') {
  description('Test and acceptance deployment stage - confidential')
  recurse(true)
  jobs {
    regex('.*tst-sec.*')
  }
}

listView('3.5.edu-sec') {
  description('Education deployment stage - confidential')
  recurse(true)
  jobs {
    regex('.*edu-sec.*')
  }
}

listView('3.6.prd-sec') {
  description('Production deployment stage - confidential')
  recurse(true)
  jobs {
    regex('.*prd-sec.*')
  }
}

