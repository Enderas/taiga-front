###
# Copyright (C) 2014-2017 Andrey Antukh <niwi@niwi.nz>
# Copyright (C) 2014-2017 Jesús Espino Garcia <jespinog@gmail.com>
# Copyright (C) 2014-2017 David Barragán Merino <bameda@dbarragan.com>
# Copyright (C) 2014-2017 Alejandro Alonso <alejandro.alonso@kaleidos.net>
# Copyright (C) 2014-2017 Juan Francisco Alcántara <juanfran.alcantara@kaleidos.net>
# Copyright (C) 2014-2017 Xavi Julian <xavier.julian@kaleidos.net>
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
# File: modules/admin/project-profile.coffee
###

taiga = @.taiga

mixOf = @.taiga.mixOf
trim = @.taiga.trim
toString = @.taiga.toString
joinStr = @.taiga.joinStr
groupBy = @.taiga.groupBy
bindOnce = @.taiga.bindOnce
debounce = @.taiga.debounce
getDefaulColorList = @.taiga.getDefaulColorList


module = angular.module("taigaAdmin")

#############################################################################
## Project values section Controller
#############################################################################

class ProjectValuesSectionController extends mixOf(taiga.Controller, taiga.PageMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgConfirm",
        "$tgResources",
        "$routeParams",
        "$q",
        "$tgLocation",
        "$tgNavUrls",
        "tgAppMetaService",
        "$translate",
        "tgErrorHandlingService",
        "tgProjectService"
    ]

    constructor: (@scope, @rootscope, @repo, @confirm, @rs, @params, @q, @location, @navUrls,
                  @appMetaService, @translate, @errorHandlingService, @projectService) ->
        @scope.project = {}

        @.loadInitialData()

        sectionName = @translate.instant(@scope.sectionName)

        title = @translate.instant("ADMIN.PROJECT_VALUES.PAGE_TITLE", {
            "sectionName": sectionName,
            "projectName": @scope.project.name
        })

        description = @scope.project.description
        @appMetaService.setAll(title, description)

    loadProject: ->
        project = @projectService.project.toJS()

        if not project.i_am_admin
            @errorHandlingService.permissionDenied()

        @scope.projectId = project.id
        @scope.project = project
        @scope.$emit('project:loaded', project)
        return project

    loadInitialData: ->
        promise = @.loadProject()
        return promise


module.controller("ProjectValuesSectionController", ProjectValuesSectionController)

#############################################################################
## Project values Controller
#############################################################################

class ProjectValuesController extends taiga.Controller
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgConfirm",
        "$tgResources",
    ]

    constructor: (@scope, @rootscope, @repo, @confirm, @rs) ->
        @scope.$on("admin:project-values:move", @.moveValue)

        unwatch = @scope.$watch "resource", (resource) =>
            if resource
                @.loadValues()
                unwatch()
    loadValues: =>
        return @rs[@scope.resource].listValues(@scope.projectId, @scope.type).then (values) =>
            @scope.values = values
            @scope.maxValueOrder = _.maxBy(values, "order").order
            return values

    moveValue: (ctx, itemValue, itemIndex) =>
        values = @scope.values
        r = values.indexOf(itemValue)
        values.splice(r, 1)
        values.splice(itemIndex, 0, itemValue)
        _.each values, (value, index) ->
            value.order = index

        @repo.saveAll(values)

module.controller("ProjectValuesController", ProjectValuesController)


#############################################################################
## Project values directive
#############################################################################

ProjectValuesDirective = ($log, $repo, $confirm, $location, animationFrame, $translate, $rootscope, projectService) ->
    ## Drag & Drop Link

    linkDragAndDrop = ($scope, $el, $attrs) ->
        oldParentScope = null
        newParentScope = null
        itemEl = null
        tdom = $el.find(".sortable")

        drake = dragula([tdom[0]], {
            direction: 'vertical',
            copySortSource: false,
            copy: false,
            mirrorContainer: tdom[0],
            moves: (item) -> return $(item).is('div[tg-bind-scope]')
        })

        drake.on 'dragend', (item) ->
            itemEl = $(item)
            itemValue = itemEl.scope().value
            itemIndex = itemEl.index()
            $scope.$broadcast("admin:project-values:move", itemValue, itemIndex)

        scroll = autoScroll(window, {
            margin: 20,
            pixels: 30,
            scrollWhenOutside: true,
            autoScroll: () ->
                return this.down && drake.dragging
        })

        $scope.$on "$destroy", ->
            $el.off()
            drake.destroy()

    ## Value Link

    linkValue = ($scope, $el, $attrs) ->
        $ctrl = $el.controller()
        valueType = $attrs.type
        objName = $attrs.objname

        initializeNewValue = ->
            $scope.newValue = {
                "name": ""
                "is_closed": false
                "is_archived": false
            }

        initializeTextTranslations = ->
            $scope.addNewElementText = $translate.instant(
                "ADMIN.PROJECT_VALUES_#{objName.toUpperCase()}.ACTION_ADD"
            )

        initializeNewValue()
        initializeTextTranslations()

        $rootscope.$on "$translateChangeEnd", ->
            $scope.$evalAsync(initializeTextTranslations)

        goToBottomList = (focus = false) =>
            table = $el.find(".table-main")

            $(document.body).scrollTop(table.offset().top + table.height())

            if focus
                $el.find(".new-value input:visible").first().focus()

        saveValue = (target) ->
            formEl = target.parents("form")
            form = formEl.checksley()
            return if not form.validate()

            value = formEl.scope().value
            promise = $repo.save(value)
            promise.then =>
                row = target.parents(".row.table-main")
                row.addClass("hidden")
                row.siblings(".visualization").removeClass('hidden')

                projectService.fetchProject()

            promise.then null, (data) ->
                form.setErrors(data)

        saveNewValue = (target) ->
            formEl = target.parents("form")
            form = formEl.checksley()
            return if not form.validate()

            $scope.newValue.project = $scope.project.id

            $scope.newValue.order = if $scope.maxValueOrder then $scope.maxValueOrder + 1 else 1

            promise = $repo.create(valueType, $scope.newValue)
            promise.then (data) =>
                target.addClass("hidden")

                $scope.values.push(data)
                $scope.maxValueOrder = data.order
                initializeNewValue()

            promise.then null, (data) ->
                form.setErrors(data)

        cancel = (target) ->
            row = target.parents(".row.table-main")
            formEl = target.parents("form")
            value = formEl.scope().value
            $scope.$apply ->
                row.addClass("hidden")
                value.revert()
                row.siblings(".visualization").removeClass('hidden')

        $el.on "click", ".show-add-new", (event) ->
            event.preventDefault()
            $el.find(".new-value").removeClass('hidden')

            goToBottomList(true)

        $el.on "click", ".add-new", debounce 2000, (event) ->
            event.preventDefault()
            target = $el.find(".new-value")
            saveNewValue(target)

        $el.on "click", ".delete-new", (event) ->
            event.preventDefault()
            $el.find(".new-value").addClass("hidden")
            initializeNewValue()

        $el.on "click", ".edit-value", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)

            row = target.parents(".row.table-main")
            row.addClass("hidden")

            editionRow = row.siblings(".edition")
            editionRow.removeClass('hidden')
            editionRow.find('input:visible').first().focus().select()

        $el.on "keyup", ".new-value input", (event) ->
            if event.keyCode == 13
                target = $el.find(".new-value")
                saveNewValue(target)
            else if event.keyCode == 27
                $el.find(".new-value").addClass("hidden")
                initializeNewValue()

        $el.on "click", ".save", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            saveValue(target)

        $el.on "click", ".cancel", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            cancel(target)

        $el.on "click", ".delete-value", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.parents("form")
            value = formEl.scope().value

            choices = {}
            _.each $scope.values, (option) ->
                if value.id != option.id
                    choices[option.id] = option.name

            subtitle = value.name

            if _.keys(choices).length == 0
                return $confirm.error($translate.instant("ADMIN.PROJECT_VALUES.ERROR_DELETE_ALL"))

            title = $translate.instant("ADMIN.COMMON.TITLE_ACTION_DELETE_VALUE")
            text = $translate.instant("ADMIN.PROJECT_VALUES.REPLACEMENT")

            $confirm.askChoice(title, subtitle, choices, text).then (response) ->
                onSucces = ->
                    $ctrl.loadValues().finally ->
                        response.finish()
                onError = ->
                    $confirm.notify("error")
                $repo.remove(value, {"moveTo": response.selected}).then(onSucces, onError)

    link = ($scope, $el, $attrs) ->
        linkDragAndDrop($scope, $el, $attrs)
        linkValue($scope, $el, $attrs)

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgProjectValues", ["$log", "$tgRepo", "$tgConfirm", "$tgLocation", "animationFrame",
                                     "$translate", "$rootScope", "tgProjectService", ProjectValuesDirective])


#############################################################################
## Color selection directive
#############################################################################

ColorSelectionDirective = () ->
    ## Color selection Link

    link = ($scope, $el, $attrs, $model) ->
        $scope.colorList = getDefaulColorList()

        $scope.allowEmpty = false
        if $attrs.tgAllowEmpty
            $scope.allowEmpty = true

        $ctrl = $el.controller()

        $scope.$watch $attrs.ngModel, (element) ->
            $scope.color = element.color

        $el.on "click", ".current-color", (event) ->
            # Showing the color selector
            event.preventDefault()
            event.stopPropagation()
            target = angular.element(event.currentTarget)
            $(".select-color").hide()
            target.siblings(".select-color").show()
            # Hide when click outside
            body = angular.element("body")
            body.on "click", (event) =>
                if angular.element(event.target).parent(".select-color").length == 0
                    $el.find(".select-color").hide()
                    body.unbind("click")

        $el.on "click", ".select-color .color", (event) ->
            # Selecting one color on color selector
            event.preventDefault()
            target = angular.element(event.currentTarget)
            $scope.$apply ->
                $model.$modelValue.color = target.data("color")
            $el.find(".select-color").hide()

        $el.on "click", ".select-color .selected-color", (event) ->
            event.preventDefault()
            $scope.$apply ->
                $model.$modelValue.color = $scope.color
            $el.find(".select-color").hide()

        $el.on "keyup", "input", (event) ->
            event.stopPropagation()
            if event.keyCode == 13
                $scope.$apply ->
                    $model.$modelValue.color = $scope.color
                $el.find(".select-color").hide()

            else if event.keyCode == 27
                $el.find(".select-color").hide()

        $scope.$on "$destroy", ->
            $el.off()

      return {
          link: link
          require:"ngModel"
      }

module.directive("tgColorSelection", ColorSelectionDirective)


#############################################################################
## Custom Attributes Controller
#############################################################################

# Custom attributes types (see taiga-back/taiga/projects/custom_attributes/choices.py)
TEXT_TYPE = "text"
MULTILINE_TYPE = "multiline"
RICHTEXT_TYPE = "richtext"
DATE_TYPE = "date"
URL_TYPE = "url"


TYPE_CHOICES = [
    {
        key: TEXT_TYPE,
        name: "ADMIN.CUSTOM_FIELDS.FIELD_TYPE_TEXT"
    },
    {
        key: MULTILINE_TYPE,
        name: "ADMIN.CUSTOM_FIELDS.FIELD_TYPE_MULTI"
    },
    {
        key: RICHTEXT_TYPE,
        name: "ADMIN.CUSTOM_FIELDS.FIELD_TYPE_RICHTEXT"
    },
    {
        key: DATE_TYPE,
        name: "ADMIN.CUSTOM_FIELDS.FIELD_TYPE_DATE"
    },
    {
        key: URL_TYPE,
        name: "ADMIN.CUSTOM_FIELDS.FIELD_TYPE_URL"
    }
]

class ProjectCustomAttributesController extends mixOf(taiga.Controller, taiga.PageMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgResources",
        "$routeParams",
        "$q",
        "$tgLocation",
        "$tgNavUrls",
        "tgAppMetaService",
        "$translate",
        "tgProjectService"
    ]

    constructor: (@scope, @rootscope, @repo, @rs, @params, @q, @location, @navUrls, @appMetaService,
                  @translate, @projectService) ->
        @scope.TYPE_CHOICES = TYPE_CHOICES
        @scope.project = @projectService.project.toJS()
        @scope.projectId = @scope.project.id

        sectionName = @translate.instant(@scope.sectionName)
        title = @translate.instant("ADMIN.CUSTOM_ATTRIBUTES.PAGE_TITLE", {
            "sectionName": sectionName,
            "projectName": @scope.project.name
        })
        description = @scope.project.description
        @appMetaService.setAll(title, description)

        @scope.init = (type) =>
            @scope.type = type
            @.loadCustomAttributes()

    #########################
    # Custom Attribute
    #########################

    loadCustomAttributes: =>
        return @rs.customAttributes[@scope.type].list(@scope.projectId).then (customAttributes) =>
            @scope.customAttributes = customAttributes
            @scope.maxOrder = _.maxBy(customAttributes, "order")?.order
            return customAttributes

    createCustomAttribute: (attrValues) =>
        return @repo.create("custom-attributes/#{@scope.type}", attrValues)

    saveCustomAttribute: (attrModel) =>
        return @repo.save(attrModel)

    deleteCustomAttribute: (attrModel) =>
        return @repo.remove(attrModel)

    moveCustomAttributes: (attrModel, newIndex) =>
        customAttributes = @scope.customAttributes
        r = customAttributes.indexOf(attrModel)
        customAttributes.splice(r, 1)
        customAttributes.splice(newIndex, 0, attrModel)

        _.each customAttributes, (val, idx) ->
            val.order = idx

        @repo.saveAll(customAttributes)


module.controller("ProjectCustomAttributesController", ProjectCustomAttributesController)


#############################################################################
## Custom Attributes Directive
#############################################################################

ProjectCustomAttributesDirective = ($log, $confirm, animationFrame, $translate) ->
    link = ($scope, $el, $attrs) ->
        $ctrl = $el.controller()

        $scope.$on "$destroy", ->
            $el.off()

        ##################################
        # Drag & Drop
        ##################################
        sortableEl = $el.find(".js-sortable")
        drake = dragula([sortableEl[0]], {
            direction: 'vertical',
            copySortSource: false,
            copy: false,
            mirrorContainer: sortableEl[0],
            moves: (item) -> return $(item).is('div[tg-bind-scope]')
        })

        drake.on 'dragend', (item) ->
            itemEl = $(item)
            itemAttr = itemEl.scope().attr
            itemIndex = itemEl.index()
            $ctrl.moveCustomAttributes(itemAttr, itemIndex)

        ##################################
        # New custom attribute
        ##################################

        showCreateForm = ->
            $el.find(".js-new-custom-field").removeClass("hidden")
            $el.find(".js-new-custom-field input:visible").first().focus()

        hideCreateForm = ->
            $el.find(".js-new-custom-field").addClass("hidden")

        showAddButton = ->
            $el.find(".js-add-custom-field-button").removeClass("hidden")

        hideAddButton = ->
            $el.find(".js-add-custom-field-button").addClass("hidden")

        showCancelButton = ->
            $el.find(".js-cancel-new-custom-field-button").removeClass("hidden")

        hideCancelButton = ->
            $el.find(".js-cancel-new-custom-field-button").addClass("hidden")

        resetNewAttr = ->
            $scope.newAttr = {}

        create = (formEl) ->
            form = formEl.checksley()
            return if not form.validate()

            onSucces = =>
                $ctrl.loadCustomAttributes()
                hideCreateForm()
                resetNewAttr()
                $confirm.notify("success")

            onError = (data) =>
                form.setErrors(data)

            attr = $scope.newAttr
            attr.project = $scope.projectId
            attr.order = if $scope.maxOrder then $scope.maxOrder + 1 else 1

            $ctrl.createCustomAttribute(attr).then(onSucces, onError)

        cancelCreate = ->
            hideCreateForm()
            resetNewAttr()

        $scope.$watch "customAttributes", (customAttributes) ->
            return if not customAttributes

            if customAttributes.length == 0
                hideCancelButton()
                hideAddButton()
                showCreateForm()
            else
                hideCreateForm()
                showAddButton()
                showCancelButton()

        $el.on "click", ".js-add-custom-field-button", (event) ->
            event.preventDefault()
            showCreateForm()

        $el.on "click", ".js-create-custom-field-button", debounce 2000, (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.closest("form")

            create(formEl)

        $el.on "click", ".js-cancel-new-custom-field-button", (event) ->
            event.preventDefault()
            cancelCreate()

        $el.on "keyup", ".js-new-custom-field input", (event) ->
            if event.keyCode == 13 # Enter
                target = angular.element(event.currentTarget)
                formEl = target.closest("form")
                create(formEl)
            else if event.keyCode == 27 # Esc
                cancelCreate()

        ##################################
        # Edit custom attribute
        ##################################

        showEditForm = (formEl) ->
            formEl.find(".js-view-custom-field").addClass("hidden")
            formEl.find(".js-edit-custom-field").removeClass("hidden")
            formEl.find(".js-edit-custom-field input:visible").first().focus().select()

        hideEditForm = (formEl) ->
            formEl.find(".js-edit-custom-field").addClass("hidden")
            formEl.find(".js-view-custom-field").removeClass("hidden")

        revertChangesInCustomAttribute = (formEl) ->
            $scope.$apply ->
                formEl.scope().attr.revert()

        update = (formEl) ->
            form = formEl.checksley()
            return if not form.validate()

            onSucces = =>
                $ctrl.loadCustomAttributes()
                hideEditForm(formEl)
                $confirm.notify("success")

            onError = (data) =>
                form.setErrors(data)

            attr = formEl.scope().attr
            $ctrl.saveCustomAttribute(attr).then(onSucces, onError)

        cancelUpdate = (formEl) ->
            hideEditForm(formEl)
            revertChangesInCustomAttribute(formEl)

        $el.on "click", ".js-edit-custom-field-button", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.closest("form")

            showEditForm(formEl)

        $el.on "click", ".js-update-custom-field-button", debounce 2000, (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.closest("form")

            update(formEl)

        $el.on "click", ".js-cancel-edit-custom-field-button", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.closest("form")

            cancelUpdate(formEl)

        $el.on "keyup", ".js-edit-custom-field input", (event) ->
            if event.keyCode == 13 # Enter
                target = angular.element(event.currentTarget)
                formEl = target.closest("form")
                update(formEl)
            else if event.keyCode == 27 # Esc
                target = angular.element(event.currentTarget)
                formEl = target.closest("form")
                cancelUpdate(formEl)

        ##################################
        # Delete custom attribute
        ##################################

        deleteCustomAttribute = (formEl) ->
            attr = formEl.scope().attr
            message = attr.name

            title = $translate.instant("COMMON.CUSTOM_ATTRIBUTES.DELETE")
            text = $translate.instant("COMMON.CUSTOM_ATTRIBUTES.CONFIRM_DELETE")

            $confirm.ask(title, text, message).then (response) ->
                onSucces = ->
                    $ctrl.loadCustomAttributes().finally -> response.finish()

                onError = ->
                    $confirm.notify("error", null, "We have not been able to delete '#{message}'.")

                $ctrl.deleteCustomAttribute(attr).then(onSucces, onError)

        $el.on "click", ".js-delete-custom-field-button", debounce 2000, (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.closest("form")

            deleteCustomAttribute(formEl)

    return {link: link}

module.directive("tgProjectCustomAttributes", ["$log", "$tgConfirm", "animationFrame", "$translate",
                                               ProjectCustomAttributesDirective])


#############################################################################
## Tags Controller
#############################################################################

class ProjectTagsController extends taiga.Controller
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgConfirm",
        "$tgResources",
        "$tgModel",
        "tgProjectService"
    ]

    constructor: (@scope, @rootscope, @repo, @confirm, @rs, @model, @projectService) ->
        @.loading = true
        @.loadTags()

    loadTags: =>
        project = @projectService.project.toJS()
        return @rs.projects.tagsColors(project.id).then (tags) =>
            @scope.projectTagsAll = _.map tags.getAttrs(), (color, name) =>
                @model.make_model('tag', {name: name, color: color})
            @.filterAndSortTags()
            @.loading = false

    filterAndSortTags: =>
        @scope.projectTags = _.sortBy @scope.projectTagsAll, (it) -> it.name.toLowerCase()

        @scope.projectTags = _.filter(
            @scope.projectTags,
            (tag) => tag.name.indexOf(@scope.tagsFilter.name) != -1
        )

    createTag: (tag, color) =>
        return @rs.projects.createTag(@scope.projectId, tag, color)

    editTag: (from_tag, to_tag, color) =>
        if from_tag == to_tag
            to_tag = null

        return @rs.projects.editTag(@scope.projectId, from_tag, to_tag, color)

    deleteTag: (tag) =>
        @scope.loadingDelete = true
        return @rs.projects.deleteTag(@scope.projectId, tag).finally =>
            @scope.loadingDelete = false

    startMixingTags: (tag) =>
        @scope.mixingTags.toTag = tag.name

    toggleMixingFromTags: (tag) =>
        if tag.name != @scope.mixingTags.toTag
            index = @scope.mixingTags.fromTags.indexOf(tag.name)
            if index == -1
                @scope.mixingTags.fromTags.push(tag.name)
            else
                @scope.mixingTags.fromTags.splice(index, 1)

    confirmMixingTags: () =>
        toTag = @scope.mixingTags.toTag
        fromTags = @scope.mixingTags.fromTags
        @scope.loadingMixing = true
        @rs.projects.mixTags(@scope.projectId, toTag, fromTags)
            .then =>
                @.cancelMixingTags()
                @.loadTags()
            .finally =>
                @scope.loadingMixing = false

    cancelMixingTags: () =>
        @scope.mixingTags.toTag = null
        @scope.mixingTags.fromTags = []

    mixingClass: (tag) =>
        if @scope.mixingTags.toTag != null
            if tag.name == @scope.mixingTags.toTag
                return "mixing-tags-to"
            else if @scope.mixingTags.fromTags.indexOf(tag.name) != -1
                return "mixing-tags-from"

module.controller("ProjectTagsController", ProjectTagsController)


#############################################################################
## Tags directive
#############################################################################

ProjectTagsDirective = ($log, $repo, $confirm, $location, animationFrame, $translate, $rootscope) ->
    link = ($scope, $el, $attrs) ->
        $window = $(window)
        $ctrl = $el.controller()
        valueType = $attrs.type
        objName = $attrs.objname

        initializeNewValue = ->
            $scope.newValue = {
                "tag": ""
                "color": ""
            }

        initializeTagsFilter = ->
            $scope.tagsFilter = {
                "name": ""
            }

        initializeMixingTags = ->
            $scope.mixingTags = {
                "toTag": null,
                "fromTags": []
            }

        initializeTextTranslations = ->
            $scope.addNewElementText = $translate.instant("ADMIN.PROJECT_VALUES_TAGS.ACTION_ADD")

        initializeNewValue()
        initializeTagsFilter()
        initializeMixingTags()
        initializeTextTranslations()

        $rootscope.$on "$translateChangeEnd", ->
            $scope.$evalAsync(initializeTextTranslations)

        goToBottomList = (focus = false) =>
            table = $el.find(".table-main")

            $(document.body).scrollTop(table.offset().top + table.height())

            if focus
                $el.find(".new-value input:visible").first().focus()

        saveValue = (target) =>
            formEl = target.parents("form")
            form = formEl.checksley()
            return if not form.validate()

            tag = formEl.scope().tag
            originalTag = tag.clone()
            originalTag.revert()

            $scope.loadingEdit = true
            promise = $ctrl.editTag(originalTag.name, tag.name, tag.color)
            promise.then =>
                $ctrl.loadTags().then =>
                    row = target.parents(".row.table-main")
                    row.addClass("hidden")
                    $scope.loadingEdit = false
                    row.siblings(".visualization").removeClass('hidden')

            promise.then null, (response) ->
                $scope.loadingEdit = false
                form.setErrors(response.data)

        saveNewValue = (target) =>
            formEl = target.parents("form")
            formEl = target
            form = formEl.checksley()
            return if not form.validate()

            $scope.loadingCreate = true
            promise = $ctrl.createTag($scope.newValue.tag, $scope.newValue.color)
            promise.then (data) =>
                $ctrl.loadTags().then =>
                    $scope.loadingCreate = false
                    target.addClass("hidden")
                    initializeNewValue()

            promise.then null, (response) ->
                $scope.loadingCreate = false
                form.setErrors(response.data)

        cancel = (target) ->
            row = target.parents(".row.table-main")
            formEl = target.parents("form")
            tag = formEl.scope().tag

            $scope.$apply ->
                row.addClass("hidden")
                tag.revert()
                row.siblings(".visualization").removeClass('hidden')

        $scope.$watch "tagsFilter.name", (tagsFilter) ->
            $ctrl.filterAndSortTags()

        $window.on "keyup", (event) ->
            if event.keyCode == 27
                $scope.$apply ->
                    initializeMixingTags()

        $el.on "click", ".show-add-new", (event) ->
            event.preventDefault()
            $el.find(".new-value").removeClass('hidden')

        $el.on "click", ".add-new", debounce 2000, (event) ->
            event.preventDefault()
            target = $el.find(".new-value")
            saveNewValue(target)

        $el.on "click", ".delete-new", (event) ->
            event.preventDefault()
            $el.find(".new-value").addClass("hidden")
            initializeNewValue()

        $el.on "click", ".mix-tags", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            $scope.$apply ->
                $ctrl.startMixingTags(target.parents('form').scope().tag)

        $el.on "click", ".mixing-row", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            $scope.$apply ->
                $ctrl.toggleMixingFromTags(target.parents('form').scope().tag)

        $el.on "click", ".mixing-confirm", (event) ->
            event.preventDefault()
            event.stopPropagation()
            $scope.$apply ->
                $ctrl.confirmMixingTags()

        $el.on "click", ".mixing-cancel", (event) ->
            event.preventDefault()
            event.stopPropagation()
            $scope.$apply ->
                $ctrl.cancelMixingTags()

        $el.on "click", ".edit-value", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)

            row = target.parents(".row.table-main")
            row.addClass("hidden")

            editionRow = row.siblings(".edition")
            editionRow.removeClass('hidden')
            editionRow.find('input:visible').first().focus().select()

        $el.on "keyup", ".new-value input", (event) ->
            if event.keyCode == 13
                target = $el.find(".new-value")
                saveNewValue(target)
            else if event.keyCode == 27
                $el.find(".new-value").addClass("hidden")
                initializeNewValue()

        $el.on "keyup", ".status-name input", (event) ->
            target = angular.element(event.currentTarget)
            if event.keyCode == 13
                saveValue(target)
            else if event.keyCode == 27
                cancel(target)

        $el.on "click", ".save", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            saveValue(target)

        $el.on "click", ".cancel", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            cancel(target)

        $el.on "click", ".delete-tag", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.parents("form")
            tag = formEl.scope().tag

            title = $translate.instant("ADMIN.COMMON.TITLE_ACTION_DELETE_TAG")

            $confirm.askOnDelete(title, tag.name).then (response) ->
                onSucces = ->
                    $ctrl.loadTags().finally ->
                        response.finish()
                onError = ->
                    $confirm.notify("error")
                $ctrl.deleteTag(tag.name).then(onSucces, onError)

        $scope.$on "$destroy", ->
            $el.off()
            $window.off()

    return {link:link}

module.directive("tgProjectTags", ["$log", "$tgRepo", "$tgConfirm", "$tgLocation", "animationFrame",
                                   "$translate", "$rootScope", ProjectTagsDirective])
