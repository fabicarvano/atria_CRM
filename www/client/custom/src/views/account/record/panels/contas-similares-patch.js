import { api } from 'common/js/api';

export default {
    data() {
        return {
            contasSimilares: [],
            carregando: false,
            enriched: false,
            contadorDisponiveis: 0,
            mensagem: ''
        };
    },
    props: ['record'],
    mounted() {
        this.enriched = !!this.record.enriquecidaLinkedin;
        if (this.enriched) {
            this.listarContasSimilares();
        } else {
            this.mensagem = "Esta conta ainda não foi enriquecida e não possui contas similares.";
        }
    },
    methods: {
        listarContasSimilares() {
            this.carregando = true;
            api.post('Account/listarContasSimilares', { accountId: this.record.id })
                .then(response => {
                    const similares = response.data || [];
                    this.contasSimilares = similares.filter(s => s.exists_in_crm === 0 && s.is_created === 0);
                    this.contadorDisponiveis = this.contasSimilares.length;
                    if (this.contadorDisponiveis === 0) {
                        this.mensagem = "Nenhuma Conta Similar disponível para criação.";
                    } else {
                        this.mensagem = '';
                    }
                })
                .finally(() => { this.carregando = false; });
        },
        criarContaSimilar(similar) {
            this.carregando = true;
            api.post('Account/criarContaSimilar', { similarId: similar.id })
                .then(() => {
                    similar.is_created = 1;
                    this.contadorDisponiveis--;
                    if (this.contadorDisponiveis === 0) {
                        this.mensagem = "Nenhuma Conta Similar disponível para criação.";
                    }
                })
                .finally(() => { this.carregando = false; });
        }
    }
};
