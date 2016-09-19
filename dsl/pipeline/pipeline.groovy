deliveryPipelineView('Dummy Pipeline Example') {
  pipelineInstances(5)
    columns(1)
    sorting(Sorting.LAST_ACTIVITY)
    updateInterval(10)
    enableManualTriggers(true)
    showAvatars()
    showChangeLog()
    pipelines {
      component('Dummy Pipeline Example', 'unit_test')
    }
}
