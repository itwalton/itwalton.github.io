DateFilter = ->
  return (time) ->
    return unless time?
    moment(time).format 'MMMM Do YYYY'


DateFilter.$inject = []


angular
  .module 'app.core'
  .filter 'date', DateFilter