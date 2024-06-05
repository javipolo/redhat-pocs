# Red Hat Openshift AI

## Prerequisites

### Openshift cluster

```
# Create and install cluster
make cluster
# Check that new context is added to our list
oc config get-contexts
```

## Install RHOAI with all the dependencies

```
make deploy
```

## Known problems

### My deployment

- couldnt try mixtral LLM due to no GPU available
- Cannot load pipelines into Elyra visual editor

### IBI related

- openshift-pipelines certificate not supported by recert (GeneralTime not supported)
- RHOAI related routes are not rewritten (they stay with the seed URL)
