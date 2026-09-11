# Configuración de Hilos (Threads) reducida para ahorrar RAM
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count


port ENV.fetch("PORT", 3000)


# Esto evita que Puma cree subprocesos duplicados que colapsen la memoria RAM
workers 0

# Permitir reinicios rápidos
plugin :tmp_restart

# Ejecutar el supervisor de Solid Queue dentro de Puma (solo 1 instancia)
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"] || Rails.env.production?

# Archivo PID (opcional según el entorno)
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]