/*
 * Copyright (C) 2014-2017 Taiga Agile LLC <taiga@taiga.io>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * File: jira-import-project-form.directive.coffee
 */

export let JiraImportProjectFormDirective = () =>
    ({
        link(scope, elm, attr, ctrl) {
            return scope.$watch("vm.members", ctrl.checkUsersLimit.bind(ctrl));
        },

        templateUrl: "projects/create/jira-import/jira-import-project-form/jira-import-project-form.html",
        controller: "JiraImportProjectFormCtrl",
        controllerAs: "vm",
        bindToController: true,
        scope: {
            members: "<",
            project: "<",
            onSaveProjectDetails: "&",
            onCancelForm: "&",
            fetchingUsers: "<",
        },
    })
;
JiraImportProjectFormDirective.$inject = [];