###
# Copyright (C) 2014-2015 Taiga Agile LLC <taiga@taiga.io>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# File: epics-table.controller.coffee
###

class EpicRowController
    @.$inject = [
        "$tgConfirm",
        "tgProjectService",
        "tgEpicsService"
    ]

    constructor: (@confirm, @projectService, @epicsService) ->
        @.displayChildEpics = false
        @.displayAssignedTo = false
        @.displayStatusList = false
        @.loadingStatus = false

        # NOTE: We use project as no inmutable object to make
        #       the code compatible with the old code
        @.project = @projectService.project.toJS()

        @._calculateProgressBar()

    _calculateProgressBar: () ->
        if @.epic.getIn(['status_extra_info', 'is_closed']) == true
            @.percentage = "100%"
        else
            if @.epic.get('child_epics_counts') == 0
                @.percentage = "0%"
            else
                @.percentage = "#{@.epic.get('epic_progress')*100}%"

    canEditEpics: () ->
        return @projectService.hasPermission("modify_epic")

    toggleChildEpicList: () ->
        if !@.displayChildEpics
            @epicsService.listChildEpics(@.epic)
                .then (result) =>
                    @.ChildEpics = result.list
                    @.displayChildEpics = true
                .catch =>
                    @confirm.notify('error')
        else
            @.displayChildEpics = false

    updateStatus: (statusId) ->
        @.displayStatusList = false
        @.loadingStatus = true
        return @epicsService.updateEpicStatus(@.epic, statusId)
            .catch () =>
                @confirm.notify('error')
            .finally () =>
                @.loadingStatus = false

    updateAssignedTo: (member) ->
        @.assignLoader = true
        return @epicsService.updateEpicAssignedTo(@.epic, member?.id or null)
            .catch () =>
                @confirm.notify('error')
            .then () =>
                @.assignLoader = false

angular.module("taigaEpics").controller("EpicRowCtrl", EpicRowController)
