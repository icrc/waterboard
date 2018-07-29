var WB = WB || {};

/**
 * Simple jQuery / bootstrap dialog wrapper
 *
 * @param options
 * @returns {WB.Modal}
 * @constructor
 */
WB.Modal = function (options) {
    this.parentId = options.parentId || 'wb-history-modal';
    this._init();

    return this;
};

WB.Modal.prototype = {
    _init: function() {

        this.$modal = $('#' + this.parentId);

        this.$modalContent = $('<div class="wb-dialog-form"></div>');
        this.$modalDom = $('<div id="wb-dialog"></div>');

        this.$modalDom.append(this.$modalContent);

        this.$modal.find('.modal-body').append(this.$modalDom);

    },

    _setContent: function(content) {
        this.$modalContent.html($(content));

        return this.$modalContent;
    },

    _hide: function () {
        this.$modalContent.empty();
        this.$modalDom.dialog("close");
    },

    _show: function () {
        var self = this;
        this.$modal.modal({});
        this.$modal.on('hidden.bs.modal', function (e) {
            self._hide();
        });
    }
};

/**
 * Simple overlay based on bootstrap modal
 * @type {{show, hide}}
 */
WB.loadingModal = (function ($, templateRenderer) {
    var overlayTemplate = templateRenderer();
	var $dialog = $(overlayTemplate);
	return {
        show: function () {
			$dialog.modal({
                keyboard: false,
                show: true,
                backdrop: false
            });
		},
		hide: function () {
			$dialog.modal('hide');
		}
	};

})(jQuery, WBLib.templates.getOverlayTemplate);
/*
* WB.loadingModal.show();
* */
