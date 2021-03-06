import React from "react";
import PropTypes from "prop-types";
import { withRouter } from "react-router-dom";
import Error from "../UI/Error";
import Loading from "../UI/Loading";
import IngestSheetUpload from "./Upload";
import { useQuery } from "@apollo/react-hooks";
import { GET_PRESIGNED_URL } from "./ingestSheet.query.js";

const IngestSheetForm = ({ history, projectId }) => {
  const { loading, error, data } = useQuery(GET_PRESIGNED_URL, {
    fetchPolicy: "no-cache"
  });

  if (loading) return <Loading />;
  if (error) return <Error error={error} />;

  return (
    <div className="md:w-1/2">
      <IngestSheetUpload
        history={history}
        projectId={projectId}
        presignedUrl={data.presignedUrl.url}
      />
    </div>
  );
};

IngestSheetForm.propTypes = {
  history: PropTypes.shape({
    push: PropTypes.func.isRequired
  }).isRequired,
  projectId: PropTypes.string.isRequired
};

export default withRouter(IngestSheetForm);
