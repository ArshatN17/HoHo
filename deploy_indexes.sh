#!/bin/bash
echo "Deploying Firestore indexes..."
firebase deploy --only firestore:indexes
echo "Done!" 