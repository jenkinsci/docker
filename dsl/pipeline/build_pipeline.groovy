buildPipelineView('Build Pipeline Example') {
  filterBuildQueue()
    filterExecutors()
    title('Build Pipeline Example')
    displayedBuilds(5)
    selectedJob('unit_test')
    alwaysAllowManualTrigger()
    showPipelineParameters()
    refreshFrequency(60)
}
