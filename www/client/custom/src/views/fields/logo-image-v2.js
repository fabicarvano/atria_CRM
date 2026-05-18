define('custom:views/fields/logo-image-v2', ['views/fields/base'], function (Dep) {

    return Dep.extend({

        setup: function () {
            Dep.prototype.setup.call(this);

            console.log('[LOGO-IMAGE-V2] setup chamado');
            console.log('[LOGO-IMAGE-V2] atributos do model:', this.model.attributes);
            console.log('[LOGO-IMAGE-V2] logoUrl no setup:', this.model.get('logoUrl'));
        },

        afterRender: function () {
            Dep.prototype.afterRender.call(this);

            var logoUrl = this.model.get('logoUrl') || null;
            var name = this.model.get('name') || '';

            console.log('[LOGO-IMAGE-V2] afterRender chamado');
            console.log('[LOGO-IMAGE-V2] logoUrl:', logoUrl);
            console.log('[LOGO-IMAGE-V2] name:', name);

            var initials = '?';

            if (name && name.trim()) {
                initials = name
                    .trim()
                    .split(/\s+/)
                    .slice(0, 2)
                    .map(function (word) {
                        return word.charAt(0);
                    })
                    .join('')
                    .toUpperCase();
            }

            this.$el.empty();

            var $wrapper = $('<div>')
                .addClass('logo-image-field')
                .css({
                    display: 'flex',
                    alignItems: 'center',
                    gap: '12px',
                    marginBottom: '10px'
                });

            if (logoUrl) {
                var $img = $('<img>')
                    .attr('src', logoUrl)
                    .attr('alt', name || 'Logo')
                    .css({
                        width: '72px',
                        height: '72px',
                        borderRadius: '10px',
                        objectFit: 'contain',
                        border: '1px solid #ddd',
                        background: '#fff',
                        padding: '6px'
                    });

                $wrapper.append($img);
            } else {
                var $fallback = $('<div>')
                    .text(initials)
                    .css({
                        width: '72px',
                        height: '72px',
                        borderRadius: '10px',
                        background: '#f3f4f6',
                        border: '1px solid #ddd',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontWeight: '600',
                        fontSize: '22px',
                        color: '#555'
                    });

                $wrapper.append($fallback);
            }

            this.$el.html($wrapper);

            console.log('[LOGO-IMAGE-V2] HTML final:', this.$el.html());
        }

    });
});
