import React, { useEffect } from "react";
import { useQuery } from "@apollo/react-hooks";
import Error from "../UI/Error";
import Loading from "../UI/Loading";
import IngestSheetValidations from "./Validations";
import { GET_INGEST_SHEET_PROGRESS } from "./ingestSheet.query";
import IngestSheetAlert from "./Alert";
import PropTypes from "prop-types";
import IngestSheetActionRow from "./ActionRow";
import IngestSheetApprovedInProgress from "./ApprovedInProgress";
import IngestSheetCompleted from "./Completed";

/**
 * The following are possible status values for an Ingest Sheet)
 *

APPROVED: Approved, ingest in progress
COMPLETED: Ingest Completed
DELETED: Ingest Sheet deleted
FILE_FAIL: Errors validating csv file
ROW_FAIL: Errors in content rows
UPLOADED: Uploaded, validation in progress
VALID: Passes validation
*/

const IngestSheet = ({
  ingestSheetData,
  projectId,
  subscribeToIngestSheetUpdates
}) => {
  const { id, status } = ingestSheetData;

  const {
    data: progressData,
    loading: progressLoading,
    error: progressError,
    subscribeToMore: progressSubscribeToMore
  } = useQuery(GET_INGEST_SHEET_PROGRESS, {
    variables: { sheetId: id },
    fetchPolicy: "network-only"
  });

  useEffect(() => {
    subscribeToIngestSheetUpdates();
  }, []);

  if (progressLoading) return <Loading />;
  if (progressError) return <Error error={progressError} />;

  return (
    <>
      <IngestSheetAlert ingestSheet={ingestSheetData} />

      {["APPROVED"].indexOf(status) > -1 && (
        <IngestSheetApprovedInProgress ingestSheet={ingestSheetData} />
      )}

      {["COMPLETED"].indexOf(status) > -1 && (
        <IngestSheetCompleted sheetId={ingestSheetData.id} />
      )}

      {["VALID", "ROW_FAIL", "FILE_FAIL", "UPLOADED"].indexOf(status) > -1 && (
        <>
          <IngestSheetActionRow
            sheetId={id}
            projectId={projectId}
            status={status}
          />
          <IngestSheetValidations
            sheetId={id}
            status={status}
            initialProgress={progressData.ingestSheetProgress}
            subscribeToIngestSheetProgress={progressSubscribeToMore}
          />
        </>
      )}
    </>
  );
};

IngestSheet.propTypes = {
  ingestSheetData: PropTypes.object,
  projectId: PropTypes.string,
  subscribeToIngestSheetUpdates: PropTypes.func
};

export default IngestSheet;
