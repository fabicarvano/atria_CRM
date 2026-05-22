define('custom:views/fields/contact-photo', ['views/fields/base'], function (Dep) {
    return Dep.extend({

        setup: function () {
            Dep.prototype.setup.call(this);
        },

        afterRender: function () {
            Dep.prototype.afterRender.call(this);

            var photoUrl   = this.model.get('linkedinPhotoUrl') || null;
            var firstName  = this.model.get('firstName') || '';
            var lastName   = this.model.get('lastName') || '';
            var name       = (firstName + ' ' + lastName).trim() || this.model.get('name') || '';
            var linkedinUrl = this.model.get('linkedinUrl') || null;
            var size       = 80;

            var initials = '?';
            if (name && name.trim()) {
                var words = name.trim().split(/\s+/);
                if (words.length === 1) {
                    initials = words[0].substring(0, 2).toUpperCase();
                } else {
                    initials = (words[0][0] + words[1][0]).toUpperCase();
                }
            }

            var colors = ['#1a73e8','#34a853','#ea4335','#fbbc04','#9c27b0',
                          '#00897b','#e64a19','#3949ab','#00acc1','#43a047','#f4511e','#8e24aa'];
            var hash = 0;
            for (var i = 0; i < name.length; i++)
                hash = name.charCodeAt(i) + ((hash << 5) - hash);
            var bg = colors[Math.abs(hash) % colors.length];

            this.$el.empty();

            var $wrapper = $('<div>').css({
                display: 'flex',
                alignItems: 'center',
                padding: '4px 0 4px 0',
                gap: '14px'
            });

            var $avatarWrap = $('<div>').css({
                width: size + 'px',
                height: size + 'px',
                borderRadius: '50%',
                overflow: 'hidden',
                flexShrink: 0,
                background: '#f4f6f8',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 1px 4px rgba(0,0,0,0.12)',
                border: '2px solid #e0e4ea'
            });

            if (photoUrl) {
                var $img = $('<img>')
                    .attr('src', photoUrl)
                    .attr('alt', name || 'Foto')
                    .css({
                        width: size + 'px',
                        height: size + 'px',
                        objectFit: 'cover',
                        borderRadius: '50%',
                        display: 'block'
                    });

                // fallback para iniciais se a imagem quebrar
                $img.on('error', function () {
                    $(this).replaceWith(
                        $('<div>').text(initials).css({
                            width: size + 'px',
                            height: size + 'px',
                            background: bg,
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: Math.round(size * 0.38) + 'px',
                            fontWeight: '700',
                            color: '#fff',
                            borderRadius: '50%'
                        })
                    );
                });

                $avatarWrap.append($img);
            } else {
                var $fallback = $('<div>').text(initials).css({
                    width: size + 'px',
                    height: size + 'px',
                    background: bg,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: Math.round(size * 0.38) + 'px',
                    fontWeight: '700',
                    color: '#fff',
                    letterSpacing: '2px',
                    userSelect: 'none',
                    borderRadius: '50%'
                });
                $avatarWrap.append($fallback);
            }

            $wrapper.append($avatarWrap);

            var $info = $('<div>').css({ display: 'flex', flexDirection: 'column' });
            if (linkedinUrl) {
                var $badge = $('<a>')
                    .attr('href', linkedinUrl)
                    .attr('target', '_blank')
                    .css({
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '4px',
                        marginTop: '5px',
                        fontSize: '11px',
                        color: '#0077b5',
                        textDecoration: 'none',
                        fontWeight: '500'
                    })
                    .html('<svg viewBox="0 0 24 24" width="12" height="12" fill="#0077b5" style="flex-shrink:0"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 0 1-2.063-2.065 2.064 2.064 0 1 1 2.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg> Ver no LinkedIn');
                $info.append($badge);
            }

            $wrapper.append($info);
            this.$el.html($wrapper);
        }
    });
});
