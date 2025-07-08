# wait_for_csv label namespace
function wait_for_csv {
    local label
    local namespace
    label="-l $1"
    [[ "$2" ]] && namespace="-n $2"
    echo "Waiting for operator to be ready"
    until oc wait $namespace csv $label --for=jsonpath='{.status.phase}'=Succeeded > /dev/null 2>&1; do
        echo -n .
        sleep 1
    done
    echo
}
