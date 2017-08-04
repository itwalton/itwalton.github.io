PostController = (post, listData, PostService) ->
  @post = post

  updateVM = (data) =>
    @posts = data.posts
    @page = data.page

    @canShowPagination = data.numPages > 1
    @pageNumbers = (page for page in [1...data.numPages+1])

  @search = (q) =>
    PostService.search(q).then(updateVM)

  @list = (page) =>
    PostService.list(page).then(updateVM)

  updateVM(listData)
  return


PostController.$inject = [ 'post', 'listData', 'PostService' ]


angular
  .module 'app.post'
  .controller 'PostController', PostController