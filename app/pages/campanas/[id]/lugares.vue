<script setup>
import { ref, onMounted, computed } from 'vue'

const route = useRoute()
const supabase = useSupabaseClient()
const router = useRouter()

const cargando = ref(true)
const lugares = ref([])
const catalogoObjetos = ref([])
const lugarSeleccionado = ref(null)

// Modales
const modalLugarAbierto = ref(false)
const modalObjetoAbierto = ref(false)

// Estados de creación
const nuevoLugar = ref({ nombre: '', rareza: 'Común', objetos: [], es_comunidad: false })
const nuevoObjeto = ref({ 
  nombre: '', tipo: 'Misceláneo', rareza: 'Común', peso: 0, bono: '', 
  monedas: { pp: 0, po: 0, pp: 0, pc: 0 }, // Platino, Oro, Plata, Cobre
  lugaresVinculados: [], es_comunidad: false 
})

// Buscadores para los modales
const buscarObjeto = ref('')
const buscarLugar = ref('')

const cargarDatos = async () => {
  cargando.value = true
  const { data: objData } = await supabase.from('objetos').select('*').order('nombre')
  if (objData) catalogoObjetos.value = objData

  const { data: lugData } = await supabase.from('lugares').select('*').eq('campaign_id', route.params.id).order('nombre')
  if (lugData) lugares.value = lugData
  cargando.value = false
}

// Lógica de visualización
const obtenerObjetosDelLugar = (lugar) => {
  if (!lugar.objetos || lugar.objetos.length === 0) return []
  return catalogoObjetos.value.filter(obj => lugar.objetos.includes(obj.id))
}

const objetosFiltrados = computed(() => {
  return catalogoObjetos.value.filter(o => o.nombre.toLowerCase().includes(buscarObjeto.value.toLowerCase()))
})

const lugaresFiltrados = computed(() => {
  return lugares.value.filter(l => l.nombre.toLowerCase().includes(buscarLugar.value.toLowerCase()))
})

// Lógica de Monedas (Conversor)
// 1 Plata = 100 Cobre. 1 Oro = 10 Plata (1000 pc). 1 Platino = 10 Oro (10000 pc).
const calcularTotalCobre = (monedas) => {
  return (monedas.pp * 10000) + (monedas.po * 1000) + (monedas.plata * 100) + monedas.pc
}

const desglosarMonedas = (totalCobre) => {
  let resto = totalCobre
  const pp = Math.floor(resto / 10000); resto %= 10000;
  const po = Math.floor(resto / 1000); resto %= 1000;
  const plata = Math.floor(resto / 100); resto %= 100;
  const pc = resto;
  return { pp, po, plata, pc }
}

const formatearPrecio = (totalCobre) => {
  if (!totalCobre) return 'Gratis'
  const m = desglosarMonedas(totalCobre)
  let texto = []
  if (m.pp > 0) texto.push(`${m.pp} ppt`)
  if (m.po > 0) texto.push(`${m.po} po`)
  if (m.plata > 0) texto.push(`${m.plata} pp`)
  if (m.pc > 0) texto.push(`${m.pc} pc`)
  return texto.join(' ')
}

// Guardar Datos
const guardarLugar = async () => {
  const { data, error } = await supabase.from('lugares').insert([{
    campaign_id: route.params.id,
    nombre: nuevoLugar.value.nombre,
    rareza: nuevoLugar.value.rareza,
    objetos: nuevoLugar.value.objetos,
    es_comunidad: nuevoLugar.value.es_comunidad
  }]).select()

  if (!error) {
    lugares.value.push(data[0])
    modalLugarAbierto.value = false
    nuevoLugar.value = { nombre: '', rareza: 'Común', objetos: [], es_comunidad: false }
  }
}

const guardarObjeto = async () => {
  const totalCobre = calcularTotalCobre({
    pp: nuevoObjeto.value.monedas.pp,
    po: nuevoObjeto.value.monedas.po,
    plata: nuevoObjeto.value.monedas.plata || 0, // le pusimos plata para diferenciarlo de pp
    pc: nuevoObjeto.value.monedas.pc
  })

  // 1. Guardamos el objeto
  const { data: objInsertado, error } = await supabase.from('objetos').insert([{
    nombre: nuevoObjeto.value.nombre,
    tipo: nuevoObjeto.value.tipo,
    rareza: nuevoObjeto.value.rareza,
    peso: nuevoObjeto.value.peso,
    bono: nuevoObjeto.value.bono,
    valor_cobre: totalCobre,
    es_comunidad: nuevoObjeto.value.es_comunidad
  }]).select()

  if (!error && objInsertado) {
    catalogoObjetos.value.push(objInsertado[0])
    
    // 2. Si seleccionó lugares, actualizamos esos lugares para incluir este objeto
    if (nuevoObjeto.value.lugaresVinculados.length > 0) {
      for (const lugarId of nuevoObjeto.value.lugaresVinculados) {
        const lugarAfectado = lugares.value.find(l => l.id === lugarId)
        if (lugarAfectado) {
          const nuevosObjetos = [...(lugarAfectado.objetos || []), objInsertado[0].id]
          await supabase.from('lugares').update({ objetos: nuevosObjetos }).eq('id', lugarId)
          lugarAfectado.objetos = nuevosObjetos // actualizamos en memoria
        }
      }
    }

    modalObjetoAbierto.value = false
    nuevoObjeto.value = { nombre: '', tipo: 'Misceláneo', rareza: 'Común', peso: 0, bono: '', monedas: { pp: 0, po: 0, plata: 0, pc: 0 }, lugaresVinculados: [], es_comunidad: false }
  }
}

onMounted(() => { cargarDatos() })
</script>

<template>
  <div class="pantalla-tiendas">
    <div class="filtro-oscuro"></div>
    
    <div class="contenedor-principal">
      <div class="header-tienda">
        <div class="h-izq">
          <button @click="router.push(`/campanas/${route.params.id}`)" class="btn-regresar">← Volver al Mapa</button>
          <h1 class="titulo-epico">Mercados y Localizaciones</h1>
        </div>
        <div class="h-der">
          <button @click="modalObjetoAbierto = true" class="btn-ghost">+ Nuevo Objeto</button>
          <button @click="modalLugarAbierto = true" class="btn-accion-dm dorado">+ Fundar Asentamiento</button>
        </div>
      </div>

      <div v-if="cargando" class="cargando-txt">Buscando rutas comerciales...</div>
      
      <div v-else class="layout-tiendas">
        <div class="panel-lugares panel-glass">
          <h2 class="subtitulo">Asentamientos</h2>
          <div class="lista-lugares">
            <div v-for="lugar in lugares" :key="lugar.id" class="lugar-item" :class="{'activo': lugarSeleccionado?.id === lugar.id}" @click="lugarSeleccionado = lugar">
              <h3>{{ lugar.nombre }}</h3>
              <span class="rareza-badge">{{ lugar.rareza }}</span>
            </div>
            <div v-if="lugares.length === 0" class="txt-vacio">No hay lugares forjados.</div>
          </div>
        </div>

        <div class="panel-inventario panel-glass">
          <div v-if="!lugarSeleccionado" class="txt-vacio grande">Selecciona un lugar para ver qué mercancías ofrece.</div>
          <div v-else>
            <h2 class="subtitulo">Mercancías en {{ lugarSeleccionado.nombre }}</h2>
            <div class="grilla-objetos">
              <div v-for="obj in obtenerObjetosDelLugar(lugarSeleccionado)" :key="obj.id" class="tarjeta-objeto">
                <div class="obj-img">📦</div>
                <div class="obj-info">
                  <h4>{{ obj.nombre }}</h4>
                  <p class="obj-bono">{{ obj.bono || 'Sin atributos especiales' }}</p>
                  <div class="obj-stats">
                    <span>{{ obj.tipo }}</span>
                    <span>{{ obj.peso }} lbs</span>
                    <strong class="precio">{{ formatearPrecio(obj.valor_cobre) }}</strong>
                  </div>
                </div>
              </div>
              <div v-if="!lugarSeleccionado.objetos || lugarSeleccionado.objetos.length === 0" class="txt-vacio">Este lugar no tiene objetos registrados.</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="modalLugarAbierto" class="modal-dm-overlay" @click.self="modalLugarAbierto = false">
      <div class="modal-dm-sheet form-large">
        <h3>📍 Forjar Nuevo Asentamiento/Tienda</h3>
        <div class="inputs-fila">
          <div class="input-group flex-2">
            <label>Nombre del Lugar</label>
            <input type="text" v-model="nuevoLugar.nombre" placeholder="Ej: El Caldero Chorreante" class="input-magico" />
          </div>
          <div class="input-group flex-1">
            <label>Nivel de Rareza</label>
            <select v-model="nuevoLugar.rareza" class="input-magico">
              <option>Común (Pueblo)</option>
              <option>Poco Común (Ciudad)</option>
              <option>Raro (Mercado Negro)</option>
              <option>Épico (Santuario)</option>
              <option>Legendario (Plano astral)</option>
            </select>
          </div>
        </div>
        
        <h4 class="subtitulo-modal">Vincular Objetos Existentes</h4>
        <input type="text" v-model="buscarObjeto" placeholder="🔍 Buscar objeto por nombre..." class="input-magico mb-corto" />
        <div class="lista-checkbox">
          <label v-for="obj in objetosFiltrados" :key="obj.id" class="item-check">
            <input type="checkbox" :value="obj.id" v-model="nuevoLugar.objetos">
            <span><strong>{{ obj.nombre }}</strong> ({{ formatearPrecio(obj.valor_cobre) }}) - {{ obj.tipo }}</span>
          </label>
        </div>

        <label class="item-check toggle-comunidad mt-1 mb-1">
          <input type="checkbox" v-model="nuevoLugar.es_comunidad"> 
          <span>🌍 Compartir este lugar con la Comunidad de DMs</span>
        </label>

        <div class="acciones-modal">
          <button class="btn-cancelar" @click="modalLugarAbierto = false">Cancelar</button>
          <button class="btn-accion-dm dorado" @click="guardarLugar">Crear Lugar</button>
        </div>
      </div>
    </div>

    <div v-if="modalObjetoAbierto" class="modal-dm-overlay" @click.self="modalObjetoAbierto = false">
      <div class="modal-dm-sheet form-large">
        <h3>⚔️ Forjar Nuevo Objeto</h3>
        
        <div class="inputs-fila">
          <div class="input-group flex-2">
            <label>Nombre del Objeto</label>
            <input type="text" v-model="nuevoObjeto.nombre" placeholder="Ej: Daga Envenenada" class="input-magico" />
          </div>
          <div class="input-group flex-1">
            <label>Categoría</label>
            <select v-model="nuevoObjeto.tipo" class="input-magico">
              <option>Arma</option><option>Armadura</option><option>Consumible</option><option>Misceláneo</option><option>Material</option>
            </select>
          </div>
        </div>
        
        <div class="inputs-fila mt-corto">
          <div class="input-group flex-1">
            <label>Rareza</label>
            <select v-model="nuevoObjeto.rareza" class="input-magico">
              <option>Común</option><option>Poco Común</option><option>Raro</option><option>Épico</option><option>Legendario</option>
            </select>
          </div>
          <div class="input-group flex-1">
            <label>Peso (lbs)</label>
            <input type="number" v-model="nuevoObjeto.peso" class="input-magico" />
          </div>
          <div class="input-group flex-2">
            <label>Efecto / Bono</label>
            <input type="text" v-model="nuevoObjeto.bono" placeholder="Ej: 1d8 cortante" class="input-magico" />
          </div>
        </div>

        <h4 class="subtitulo-modal">Valor Económico</h4>
        <div class="inputs-monedas-box">
          <div class="moneda-caja ppt">
            <label>Platino (ppt)</label>
            <input type="number" v-model="nuevoObjeto.monedas.pp" min="0" />
          </div>
          <div class="moneda-caja po">
            <label>Oro (po)</label>
            <input type="number" v-model="nuevoObjeto.monedas.po" min="0" />
          </div>
          <div class="moneda-caja plata">
            <label>Plata (pp)</label>
            <input type="number" v-model="nuevoObjeto.monedas.plata" min="0" />
          </div>
          <div class="moneda-caja pc">
            <label>Cobre (pc)</label>
            <input type="number" v-model="nuevoObjeto.monedas.pc" min="0" />
          </div>
        </div>

        <h4 class="subtitulo-modal">¿Dónde se consigue este objeto? (Opcional)</h4>
        <input type="text" v-model="buscarLugar" placeholder="🔍 Buscar asentamiento..." class="input-magico mb-corto" />
        <div class="lista-checkbox corto">
          <label v-for="lugar in lugaresFiltrados" :key="lugar.id" class="item-check">
            <input type="checkbox" :value="lugar.id" v-model="nuevoObjeto.lugaresVinculados">
            <span>{{ lugar.nombre }}</span>
          </label>
        </div>

        <label class="item-check toggle-comunidad mt-1 mb-1">
          <input type="checkbox" v-model="nuevoObjeto.es_comunidad"> 
          <span>🌍 Compartir objeto en el Catálogo Global</span>
        </label>

        <div class="acciones-modal">
          <button class="btn-cancelar" @click="modalObjetoAbierto = false">Cancelar</button>
          <button class="btn-accion-dm dorado" @click="guardarObjeto">Añadir al Compendio</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@700&display=swap');

.pantalla-tiendas { min-height: 100vh; background-color: #050505; color: #cbd5e1; position: relative; padding: 2rem; }
.filtro-oscuro { position: absolute; inset: 0; background: radial-gradient(circle at center, #1e1b4b 0%, #000 100%); z-index: 0; opacity: 0.8; }
.contenedor-principal { position: relative; z-index: 10; max-width: 1300px; margin: 0 auto; }

.header-tienda { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #334155; padding-bottom: 1rem; margin-bottom: 2rem; }
.h-izq { display: flex; align-items: center; gap: 1rem;}
.h-der { display: flex; gap: 1rem; }
.titulo-epico { font-family: 'Cinzel', serif; color: #facc15; margin: 0; }
.btn-regresar { background: transparent; border: 1px solid #475569; color: #94a3b8; padding: 0.5rem 1rem; border-radius: 6px; cursor: pointer; }
.btn-ghost { background: transparent; border: 1px dashed #3b82f6; color: #3b82f6; padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer; font-weight: bold; }
.btn-accion-dm.dorado { background: #b45309; color: white; border: none; padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer; font-weight: bold; }

.layout-tiendas { display: grid; grid-template-columns: 350px 1fr; gap: 2rem; align-items: start; }
.panel-glass { background: #0a0a0c; border: 1px solid #1e293b; padding: 1.5rem; border-radius: 12px; }
.subtitulo { font-family: 'Cinzel', serif; color: white; margin-top: 0; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; }

.lista-lugares { display: flex; flex-direction: column; gap: 0.8rem; }
.lugar-item { background: #111; border: 1px solid #334155; padding: 1rem; border-radius: 8px; cursor: pointer; transition: 0.2s; display: flex; justify-content: space-between; align-items: center; }
.lugar-item:hover { border-color: #6366f1; background: #1e1b4b; }
.lugar-item.activo { border-color: #818cf8; background: #312e81; }
.lugar-item h3 { margin: 0; font-size: 1.1rem; color: #e0e7ff; }
.rareza-badge { font-size: 0.7rem; background: #000; padding: 0.2rem 0.5rem; border-radius: 4px; color: #a5b4fc; }

.grilla-objetos { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; }
.tarjeta-objeto { background: #111; border: 1px solid #334155; border-radius: 8px; display: flex; gap: 1rem; padding: 1rem; transition: 0.2s;}
.tarjeta-objeto:hover { border-color: #facc15; background: #1a1a10; }
.obj-img { width: 60px; height: 60px; background: #000; border-radius: 6px; display: flex; align-items: center; justify-content: center; font-size: 2rem; flex-shrink: 0; border: 1px solid #475569; }
.obj-info { flex-grow: 1; }
.obj-info h4 { margin: 0 0 0.3rem 0; color: white; font-family: 'Cinzel', serif; }
.obj-bono { font-size: 0.85rem; color: #a78bfa; margin: 0 0 0.5rem 0; font-style: italic; }
.obj-stats { display: flex; justify-content: space-between; font-size: 0.8rem; color: #94a3b8; font-family: monospace; }
.precio { color: #facc15; }

.txt-vacio { text-align: center; color: #64748b; font-style: italic; padding: 2rem; }
.txt-vacio.grande { font-size: 1.2rem; padding: 5rem; border: 1px dashed #334155; border-radius: 12px; }

/* MODALES */
.modal-dm-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.85); display: flex; align-items: center; justify-content: center; z-index: 999; padding: 1rem; }
.modal-dm-sheet { background: #0a0a0c; border: 2px solid #334155; border-radius: 12px; padding: 2rem; width: 100%; box-shadow: 0 0 30px rgba(0,0,0,0.8); max-height: 90vh; overflow-y: auto;}
.form-large { max-width: 700px; }
.modal-dm-sheet h3 { font-family: 'Cinzel', serif; color: #facc15; margin: 0 0 1.5rem 0; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; }
.subtitulo-modal { color: #94a3b8; border-bottom: 1px dashed #334155; padding-bottom: 0.3rem; margin-top: 1.5rem; }

.inputs-fila { display: flex; gap: 1rem; width: 100%; }
.flex-1 { flex: 1; } .flex-2 { flex: 2; }
.input-magico { width: 100%; background: #111; border: 1px solid #475569; color: white; padding: 0.8rem; border-radius: 6px; font-size: 1rem; outline: none; }
.input-magico:focus { border-color: #3b82f6; }
.mb-corto { margin-bottom: 1rem; }
.mt-corto { margin-top: 1rem; }
.mt-1 { margin-top: 1rem; } .mb-1 { margin-bottom: 1rem; }

/* CAJA DE MONEDAS */
.inputs-monedas { display: flex; gap: 1rem; margin-top: 0.5rem; }
.moneda-caja { flex: 1; display: flex; flex-direction: column; gap: 0.3rem; text-align: center; font-size: 0.8rem; font-weight: bold; }
.moneda-caja input { background: #111; border: 1px solid #334155; color: white; padding: 0.5rem; border-radius: 6px; text-align: center; font-size: 1.1rem; }
.ppt span { color: #e2e8f0; } .po span { color: #facc15; } .plata span { color: #94a3b8; } .pc span { color: #b45309; }

/* CHECKBOXES */
.lista-checkbox { display: flex; flex-direction: column; gap: 0.4rem; max-height: 200px; overflow-y: auto; background: #000; border: 1px solid #334155; padding: 0.5rem; border-radius: 6px; }
.lista-checkbox.corto { max-height: 120px; }
.item-check { display: flex; align-items: center; gap: 0.8rem; cursor: pointer; color: #cbd5e1; font-size: 0.9rem; padding: 0.3rem; transition: 0.2s; }
.item-check:hover { background: #1e293b; border-radius: 4px; color: white; }
.item-check input { width: 16px; height: 16px; accent-color: #facc15; }

.acciones-modal { display: flex; justify-content: flex-end; gap: 1rem; margin-top: 2rem; border-top: 1px solid #1e293b; padding-top: 1.5rem; }
.btn-cancelar { background: transparent; border: 1px solid #64748b; color: #94a3b8; padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer; font-weight: bold; transition: 0.2s; }
.btn-cancelar:hover { background: #1e293b; color: white; }

/* MEJORAS DE INPUTS Y LABELS */
.input-group { display: flex; flex-direction: column; gap: 0.3rem; }
.input-group label { font-size: 0.85rem; color: #94a3b8; font-weight: bold; font-family: 'Inter', sans-serif; text-transform: uppercase; letter-spacing: 0.5px; }

/* NUEVO CAJÓN DE MONEDAS */
.inputs-monedas-box { display: flex; gap: 1rem; background: #111; padding: 1rem; border-radius: 8px; border: 1px solid #334155; }
.moneda-caja label { margin-bottom: 0.4rem; }
.moneda-caja input { width: 100%; background: #0a0a0c; border: 1px solid #475569; color: white; padding: 0.6rem; border-radius: 6px; text-align: center; font-size: 1.2rem; outline: none; transition: 0.2s; }
.moneda-caja input:focus { border-color: #3b82f6; box-shadow: 0 0 10px rgba(59,130,246,0.3); }

/* ESTILO ESPECIAL COMUNIDAD */
.toggle-comunidad { background: rgba(59, 130, 246, 0.1); border: 1px solid #3b82f6; padding: 0.8rem !important; border-radius: 8px !important; }
.toggle-comunidad span { color: #bfdbfe; font-weight: bold; }
</style>