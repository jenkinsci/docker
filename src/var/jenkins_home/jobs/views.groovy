listView('01.bld-loc') { 
  description('Build stage')
  recurse(true)
  jobs { 
    regex('.*build.*') 
  } 
}

listView('02.dev-loc') {
  description('Development deployment stage - localhost')
  recurse(true)
  jobs {
    regex('.*dev-loc.*')
  }
}

listView('03.rel-loc') {
  description('Release deployment stage - localhost')
  recurse(true)
  jobs {
    regex('.*rel-loc.*')
  }
}

listView('04.dev-pub') {
  description('Development deployment stage - public')
  recurse(true)
  jobs {
    regex('.*dev-pub.*')
  }
}

listView('05.rel-pub') {
  description('Release deployment stage - public')
  recurse(true)
  jobs {
    regex('.*rel-pub.*')
  }
}

listView('06.dem-pub') {
  description('Demo deployment stage - public')
  recurse(true)
  jobs {
    regex('.*dem-pub.*')
  }
}

listView('07.dev-sec') {
  description('Development deployment stage - secure')
  recurse(true)
  jobs {
    regex('.*dev-sec.*')
  }
}

listView('08.rel-sec') {
  description('Release deployment stage - secure')
  recurse(true)
  jobs {
    regex('.*rel-sec.*')
  }
}

listView('09.int-sec') {
  description('Integration deployment stage - confidential')
  recurse(true)
  jobs {
    regex('.*int-sec.*')
  }
}

listView('10.tst-sec') {
  description('Test and acceptance deployment stage - confidential')
  recurse(true)
  jobs {
    regex('.*tst-sec.*')
  }
}

listView('11.edu-sec') {
  description('Education deployment stage - confidential')
  recurse(true)
  jobs {
    regex('.*edu-sec.*')
  }
}

listView('12.prd-sec') {
  description('Production deployment stage - confidential')
  recurse(true)
  jobs {
    regex('.*prd-sec.*')
  }
}

