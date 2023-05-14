#!/bin/bash
#Inicializo las variables que necesito para formatear el resultado final.
header="\n %-10s %8s %10s %15s %8s %10s %11s %20s %17s\n"
divider=================================================================
divider=$divider$divider
width=120

#Gurado en el archivo ls.text la información de los procesos actuales en /proc.
ls -l /proc > ls.text; 

#Obtengo los pid de cada proceso y los guardo en pid_procesos.txt.
awk '$9 ~ /([0-9])+/ {print $9 > "pid_procesos.txt"}' ls.text;

#Obtengo para cada PID sus datos en proc/stat y los sobreescribo en datos.txt
while IFS= read -r pid; do
	FILE=/proc/$pid/stat
	#Compruebo que el proceso siga existiendo en /proc
	if test -f "$FILE"; then
		cat /proc/$pid/stat  >> datos.txt
	fi
done < pid_procesos.txt

#Guardo en el fichero sólo los valores que me interesan (PID y tiempo CPU Total)
awk '{print $1, $14+$15 > "total_time_pid_inicio.txt"}' datos.txt

#Borro el contenido de datos.txt para su posterior uso.
true > datos.txt

echo "Se han tomado los datos del punto inicial, el siguiente costará un poco más"

#Espera un segundo.
sleep 1

#Obtengo otra vez para cada PID sus datos.
while IFS= read -r pid; do
	FILE=/proc/$pid/stat
	#Compruebo que el proceso siga existiendo en /proc
	if test -f "$FILE"; then
		cat /proc/$pid/stat  >> datos_final.txt
		#Obtengo la información sobre el usuario en proc/status y lo guardo en users.txt
		grep -e '^Uid:' /proc/$pid/status | cut -d "	" -f 2 >> users.txt
		#Obtengo la información sobre el tiempo en ejecución (segundos) usando el tiempo actual y el tiempo inicial del proceso.
		expr $(date +"%s") - $(stat -c%X /proc/$pid) >> tiempos.txt
	fi
done < pid_procesos.txt

echo "Datos del segundo punto tomados! Solo falta retocar un par de cosas..."

#Junto los datos de los tres ficheros obtenidos para cada PID en un sólo archivo
paste -d' ' datos_final.txt users.txt tiempos.txt > datos_user.txt

#Obtengo los datos que me interesan.
awk '{print $1, $14+$15, $17, $23, $3, $53, $2, $54 > "total_time_pid_final.txt"}' datos_user.txt

#Junto en un fichero los datos del punto inicial con los datos actuales.
paste -d' ' total_time_pid_inicio.txt total_time_pid_final.txt > final.txt

#Obtengo los datos que me interesan de dicho fichero.
awk '{print $1, $2, $4, $5, $6, $7, $8, $9, $10 > "final2.txt"}' final.txt 

#Calculo el tiempo de CPU utilizada restando los valores de uso de CPU de inicio y final.
awk '{print $3-$2, $1, $4, $5, $6, $7, $8, $9 > "final3.txt"}' final2.txt

#Ordeno el archivo con los datos que me interesan según su uso total de CPU.
cat final3.txt | sort -k1,1nr > final_final.txt 

#Calculo el tiempo total de CPU usado por los procesos capturados, lo guardo en la variable TT para poder usarlo más adelante.
awk '{print $1 > "time.txt"}' final3.txt
TT="$(paste -sd+ time.txt | bc)"

#Calculo la memoria virtual total utilizada por los procesos capturados, lo guardo en la variable MT para poder usarlo más adelante.
awk '{print $4 > "memory.txt"}' final3.txt
MT="$(paste -sd+ memory.txt | bc)"

#Imprimo la tabla formateada con los datos que me interesan (calculo también los porcentajes necesarios).
printf "$header" "PID" "USER (ID)" "PR" "VIRT" "S" "%CPU" "%MEM" "COMMAND" "TIME (seconds)"
printf "%$width.${width}s\n" "$divider"
awk -v t=$TT -v m=$MT '{printf "%-10s %8s %10s %15s %8s %11.2f %11.4f %20s %12s\n", $2, $6, $3, $4, $5, ($1/t)*100, ($4/m)*100, $7, $8} NR==10{exit}' final_final.txt

#Para próximas ejecuciones del script, es necesario borrar el contenido de algunos archivos intermedios. 
true > datos_final.txt
true > users.txt
true > datos.txt
true > tiempos.txt
