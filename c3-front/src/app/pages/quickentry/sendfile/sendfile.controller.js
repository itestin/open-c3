(function() {
    'use strict';

    angular
        .module('openc3')
        .controller('SendfileController', SendfileController);

    function SendfileController($timeout, $state, $http, $uibModal, $scope, treeService, ngTableParams, resoureceService, $injector, $filter) {

        var vm = this;
        vm.treeid = $state.params.treeid;
        var toastr = toastr || $injector.get('toastr');
        $scope.selectedUser = 'root';

        treeService.sync.then(function(){ 
            vm.nodeStr = treeService.selectname(); 
        });

        if (vm.treeid){
            $http.get('/api/job/userlist/' + vm.treeid).then(

                function successCallback (response) {
                    if (response.data.stat){
                        $scope.allProUsers= response.data.data;
                    }else {
                        toastr.error( "获取执行账户列表失败："+response.data.info)
                    }
                },
                function errorCallback () {
                    toastr.error( "获取执行账户列表失败："+response.status)
                }
            );
        }

        vm.reload = function () {
            vm.loadover = false

            if( vm.filepath )
            {
                $http.get('/api/job/sendfile/list/' + vm.treeid + '?sudo=' + $scope.selectedUser + '&path=' + vm.filepath  ).then(
                    function successCallback(response) {
                        if (response.data.stat){
                            vm.dir_Table = new ngTableParams({count:200}, {counts:[],data:response.data.data});
                            vm.loadover = true
                        }else {
                            toastr.error( "获取目录列表失败："+response.data.info)
                        }
                    },
                    function errorCallback (response ){
                        toastr.error( "获取目录列表失败："+response.status)
                    });

                $http.get('/api/job/fileserver/' + vm.treeid ).then(
                    function successCallback(response) {
                        if (response.data.stat){
                            vm.fileserver_Table = new ngTableParams({count:15}, {counts:[],data:response.data.data});
                            vm.loadover = true
                        }else {
                            toastr.error( "获取文件管理列表失败："+response.data.info)
                        }
                    },
                    function errorCallback (response ){
                        toastr.error( "获取文件管理列表失败："+response.status)
                    });

                var nowTime = $filter('date')(new Date, "yyyy-MM-dd");

                $http.get('/api/job/task/' + vm.treeid + '?name=sendfile&time_start=' + nowTime ).then(
                    function successCallback(response) {
                        if (response.data.stat){
                            vm.sendfiletask_Table = new ngTableParams({count:15}, {counts:[],data:response.data.data.reverse()});
                            vm.loadover = true
                        }else {
                            toastr.error( "获取文件管理列表失败："+response.data.info)
                        }
                    },
                    function errorCallback (response ){
                        toastr.error( "获取文件管理列表失败："+response.status)
                    });
            }
            else
            {
                $http.get('/api/agent/nodeinfo/' + vm.treeid).then(
                    function successCallback(response) {
                        if (response.data.stat){
                            vm.machine_Table = new ngTableParams({count:10}, {counts:[],data:response.data.data.reverse()});
                            vm.loadover = true
                        }else {
                            toastr.error( "获取机器列表失败："+response.data.info)
                        }
                    },
                    function errorCallback (response ){
                        toastr.error( "获取机器列表失败："+response.status)
                    });
            }
        };

        vm.reload();

        vm.openOne = function (name) {
            vm.filepath = name;
            vm.reload();
        };

        vm.intodir = function (name) {
            vm.filepath = vm.filepath + "/" + name;
            vm.reload();
        };

        vm.backdir = function () {
            var temppath = vm.filepath.split("/");
            temppath.pop();
            vm.filepath = temppath.join("/");
            vm.reload();
        };

        vm.reset = function () {
            vm.filepath = '';
            vm.reload();
        };

        vm.startUoloadTask = function ( filename ) {
            var temppath = vm.filepath.split("/");
            var temphost = temppath.shift();
            var filepath = temppath.join("/");
 
            var post_data = { "chmod": "644", "chown" : $scope.selectedUser, "dp": "/" + filepath + "/", "dst": temphost, "dst_type" : "builtin", "name": "sendfile_upload_" + vm.filepath + "/" + filename, "sp": filename, "src": "","src_type": "fileserver", "timeout" : 300, "user": $scope.selectedUser };
            resoureceService.work.scp(vm.treeid, post_data, null)
                .then(function (repo) {
                    if (repo.stat){
                    }else{
                        toastr.error( "提交任务失败:" + repo.info )
                    }
                }, function (repo) {
                    toastr.error( "提交任务失败:" + repo )

                })
        };

        vm.startDownloadTask = function ( filename ) {
            var temppath = vm.filepath.split("/");
            var temphost = temppath.shift();
            var filepath = temppath.join("/");
 
            var post_data = { "chmod": "644", "chown" : $scope.selectedUser, "dp": "/tmp/abc/", "dst": temphost, "dst_type" : "fileserver", "name": "sendfile_download_" + vm.filepath + "/" + filename, "sp": "/" + filepath + "/" + filename, "src": temphost,"src_type": "builtin", "timeout" : 300, "user": $scope.selectedUser };
            resoureceService.work.scp(vm.treeid, post_data, null)
                .then(function (repo) {
                    if (repo.stat){
                    }else{
                        toastr.error( "提交任务失败:" + repo.info )
                    }
                }, function (repo) {
                    toastr.error( "提交任务失败:" + repo )

                })
        };

    }
})();
