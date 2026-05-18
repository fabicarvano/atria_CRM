define('custom:views/account/detail-v2', ['views/detail'], function (Dep) {

    return Dep.extend({

        afterRender: function () {
            Dep.prototype.afterRender.call(this);

            var self = this;

            setTimeout(function () {
                self.renderAccountLogo();
            }, 500);
        },

        renderAccountLogo: function () {
            var $field = this.$el.find('.field[data-name="logoUrl"]');

            if (!$field.length) {
                console.warn('[ACCOUNT-DETAIL-V2] Campo logoUrl não encontrado.');
                return;
            }

            var defaultLogo = '/client/custom/img/default-account-logo.svg';
            var logoUrl = this.model.get('logoUrl') || defaultLogo;
            var name = this.model.get('name') || 'Logo da conta';

            var html = ''
                + '<div class="logo-account-wrapper" style="display:flex;align-items:center;gap:12px;margin-bottom:10px;">'
                + '    <div style="width:72px;height:72px;border-radius:12px;background:#f3f4f6;border:1px solid #ddd;display:flex;align-items:center;justify-content:center;padding:8px;">'
                + '        <img src="' + logoUrl + '" alt="' + name + '" '
                + '             onerror="this.onerror=null;this.src=\'' + defaultLogo + '\';" '
                + '             style="max-width:52px;max-height:52px;object-fit:contain;">'
                + '    </div>'
                + '</div>';

            $field.html(html);

            console.log('[ACCOUNT-DETAIL-V2] Logo renderizada:', logoUrl);
        }

    });
});
